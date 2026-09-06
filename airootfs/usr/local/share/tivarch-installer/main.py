#!/usr/bin/env python3
import sys
import os
import glob
import json
import time
import subprocess
import urllib.request
from PySide6.QtCore import QObject, Signal, Slot, Property, QThread
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


class InstallWorker(QThread):
    progress = Signal(int, str)
    finished = Signal(bool, str)

    def __init__(self, target_disk, timezone, keymap, hostname, username, password, make_root):
        super().__init__()
        self.target_disk = target_disk
        self.timezone = timezone
        self.keymap = keymap
        self.hostname = hostname.strip() if hostname else "tivarch"
        self.username = username.strip().lower() if username else "tivarch"
        self.password = password
        self.make_root = make_root
        self.current_percent = 0

    def run_cmd(self, cmd, desc):
        self.progress.emit(self.current_percent, desc)
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if res.returncode != 0:
            raise RuntimeError(f"Failed at: {desc}\nCommand: {cmd}\nError: {res.stderr.strip()}")

    def resolve_part(self, disk, part_num):
        """Resolves correct device partition node names (e.g. nvme0n1p1, vda1, sda1)."""
        if any(prefix in disk for prefix in ["nvme", "nbd", "mmcblk", "loop"]):
            return f"{disk}p{part_num}"
        return f"{disk}{part_num}"

    def run(self):
        try:
            self.current_percent = 5
            # 1. Clean previous mounts and signatures
            self.run_cmd("umount -R /mnt 2>/dev/null || true", "Unmounting target mounts")
            self.run_cmd(f"wipefs -a -f {self.target_disk}* 2>/dev/null || true", "Wiping existing partition signatures")

            # 2. Partition Disk: GPT (512MiB ESP + Remainder Root)
            self.current_percent = 15
            self.run_cmd(f"parted --script {self.target_disk} mklabel gpt", "Creating GPT partition table")
            self.run_cmd(f"parted --script {self.target_disk} mkpart 'ESP' fat32 1MiB 513MiB", "Creating EFI partition")
            self.run_cmd(f"parted --script {self.target_disk} set 1 esp on", "Enabling ESP boot flag")
            self.run_cmd(f"parted --script {self.target_disk} mkpart 'root' ext4 513MiB 100%", "Creating Root partition")

            # Allow kernel to register partitions
            self.run_cmd(f"partprobe {self.target_disk} || true", "Re-reading partition table")
            time.sleep(2)

            efi_part = self.resolve_part(self.target_disk, 1)
            root_part = self.resolve_part(self.target_disk, 2)

            # 3. Format Partitions
            self.current_percent = 25
            self.run_cmd(f"mkfs.vfat -F32 -n 'TIVARCH_ESP' {efi_part}", "Formatting FAT32 EFI partition")
            self.run_cmd(f"mkfs.ext4 -F -L 'TIVARCH_ROOT' -O fast_commit {root_part}", "Formatting Ext4 Root partition")

            # 4. Mount System Directory Tree
            self.current_percent = 35
            self.run_cmd(f"mount {root_part} /mnt", "Mounting root filesystem")
            self.run_cmd("mkdir -p /mnt/boot", "Creating /boot mountpoint")
            self.run_cmd(f"mount {efi_part} /mnt/boot", "Mounting EFI system partition")

            # 5. Clone System Image
            self.current_percent = 50
            rsync_exclude = (
                "--exclude={'/dev/*','/proc/*','/sys/*','/tmp/*','/run/*',"
                "'/mnt/*','/media/*','/lost+found','/swapfile'}"
            )
            self.run_cmd(f"rsync -aAX --info=progress2 {rsync_exclude} / /mnt/", "Transferring system files to disk")

            # 6. Generate Clean mkinitcpio & Ensure Kernel Binary Exists
            self.current_percent = 65
            self.run_cmd("rm -rf /mnt/etc/mkinitcpio.conf.d/archiso.conf /mnt/etc/mkinitcpio.conf.d/*archiso*", "Removing live-ISO initramfs hooks")

            # Copy vmlinuz from /usr/lib/modules/ if missing from /boot
            ensure_kernel_cmd = (
                "if [ ! -f /mnt/boot/vmlinuz-linux-lts ]; then "
                "  kimg=$(find /mnt/usr/lib/modules/ -name vmlinuz | head -n 1); "
                "  if [ -n \"$kimg\" ]; then "
                "    cp -f \"$kimg\" /mnt/boot/vmlinuz-linux-lts; "
                "  else "
                "    arch-chroot /mnt pacman -S --noconfirm linux-lts; "
                "  fi; "
                "fi"
            )
            self.run_cmd(ensure_kernel_cmd, "Verifying target kernel binary")

            clean_mkinitcpio = (
                "MODULES=()\n"
                "BINARIES=()\n"
                "FILES=()\n"
                "HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)\n"
            )
            with open("/mnt/etc/mkinitcpio.conf", "w") as f:
                f.write(clean_mkinitcpio)

            clean_preset = (
                "# mkinitcpio preset for standard Linux LTS deployment\n"
                "ALL_kver='/boot/vmlinuz-linux-lts'\n"
                "ALL_config='/etc/mkinitcpio.conf'\n"
                "PRESETS=('default' 'fallback')\n"
                "default_image='/boot/initramfs-linux-lts.img'\n"
                "fallback_image='/boot/initramfs-linux-lts-fallback.img'\n"
                "fallback_options='-S autodetect'\n"
            )
            os.makedirs("/mnt/etc/mkinitcpio.d", exist_ok=True)
            with open("/mnt/etc/mkinitcpio.d/linux-lts.preset", "w") as f:
                f.write(clean_preset)

            self.run_cmd("arch-chroot /mnt mkinitcpio -p linux-lts", "Generating production kernel initramfs")

            # 7. Persistent UUID-Based fstab
            self.current_percent = 75
            root_uuid = subprocess.check_output(f"blkid -s UUID -o value {root_part}", shell=True, text=True).strip()
            efi_uuid = subprocess.check_output(f"blkid -s UUID -o value {efi_part}", shell=True, text=True).strip()

            fstab_content = (
                f"# /etc/fstab: static file system information.\n"
                f"UUID={root_uuid} / ext4 rw,relatime 0 1\n"
                f"UUID={efi_uuid} /boot vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2\n"
            )
            with open("/mnt/etc/fstab", "w") as f:
                f.write(fstab_content)

            # 8. Region, Hostname, Keymap, and Network Identification
            self.current_percent = 80
            self.run_cmd(f"arch-chroot /mnt ln -sf /usr/share/zoneinfo/{self.timezone} /etc/localtime", "Configuring system timezone")
            self.run_cmd(f"echo 'KEYMAP={self.keymap}' > /mnt/etc/vconsole.conf", "Persisting console keymap")
            
            xkb_layout = {"trq": "tr", "uk": "gb"}.get(self.keymap, self.keymap)
            self.run_cmd(f"arch-chroot /mnt localectl set-x11-keymap {xkb_layout} || true", "Setting desktop XKB layout")

            self.run_cmd(f"echo '{self.hostname}' > /mnt/etc/hostname", "Setting computer hostname")
            hosts_content = (
                "127.0.0.1 localhost\n"
                "::1       localhost\n"
                f"127.0.1.1 {self.hostname}.localdomain {self.hostname}\n"
            )
            with open("/mnt/etc/hosts", "w") as f:
                f.write(hosts_content)

            # 9. User Account, Groups, and Elevation
            self.current_percent = 85
            if self.make_root or self.username == "root":
                if self.password:
                    self.run_cmd(f"echo 'root:{self.password}' | arch-chroot /mnt chpasswd", "Setting root password")
                else:
                    self.run_cmd("arch-chroot /mnt passwd -d root", "Unlocking passwordless root")
                autologin_user = "root"
            else:
                self.run_cmd(
                    f"arch-chroot /mnt useradd -m -G wheel,video,audio,input,seat,render,storage,power -s /bin/bash {self.username} || true",
                    f"Creating user '{self.username}'"
                )
                if self.password:
                    self.run_cmd(f"echo '{self.username}:{self.password}' | arch-chroot /mnt chpasswd", f"Setting password for '{self.username}'")
                else:
                    self.run_cmd(f"arch-chroot /mnt passwd -d {self.username}", f"Unlocking passwordless account for '{self.username}'")

                # Allow wheel group passwordless sudo
                os.makedirs("/mnt/etc/sudoers.d", exist_ok=True)
                with open("/mnt/etc/sudoers.d/99-tivarch-wheel", "w") as f:
                    f.write("%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n")
                self.run_cmd("chmod 0440 /mnt/etc/sudoers.d/99-tivarch-wheel", "Securing sudoers configuration")
                autologin_user = self.username

            # Configure agetty autologin on tty1
            os.makedirs("/mnt/etc/systemd/system/getty@tty1.service.d", exist_ok=True)
            with open("/mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf", "w") as f:
                f.write(
                    "[Service]\n"
                    "ExecStart=\n"
                    f"ExecStart=-/sbin/agetty -o '-p -f -- \\\\u' --noclear --autologin {autologin_user} %I $TERM\n"
                )


            # Clean Archiso live motd, issue banners, and shell prompts
            self.run_cmd("rm -f /mnt/etc/motd /mnt/etc/issue", "Removing live ISO welcome banners")
            self.run_cmd("touch /mnt/etc/motd /mnt/etc/issue", "Resetting clean login banners")
            
            # Set a clean appliance shell prompt for both root and the user
            clean_ps1 = 'export PS1="[\\u@\\h \\W]\\$ "\n'
            with open("/mnt/etc/profile.d/tivarch-prompt.sh", "w") as f:
                f.write(clean_ps1)
            self.run_cmd("chmod +x /mnt/etc/profile.d/tivarch-prompt.sh", "Setting default prompt")



            # 10. Install GRUB Bootloader with EFI Fallback
            self.current_percent = 92
            os.makedirs("/mnt/etc/default", exist_ok=True)
            grub_default = (
                'GRUB_DEFAULT=0\n'
                'GRUB_TIMEOUT=2\n'
                'GRUB_DISTRIBUTOR="TiVarch"\n'
                'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"\n'
                f'GRUB_CMDLINE_LINUX="root=UUID={root_uuid} rw"\n'
                'GRUB_DISABLE_OS_PROBER=true\n'
            )
            with open("/mnt/etc/default/grub", "w") as f:
                f.write(grub_default)

            self.run_cmd(
                "arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=TiVarch --removable --recheck",
                "Installing GRUB with removable UEFI fallback"
            )
            self.run_cmd("arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg", "Compiling grub.cfg")

            # 11. Cleanup Live Installer Services
            self.current_percent = 98
            self.run_cmd(
                "rm -f /mnt/etc/systemd/system/multi-user.target.wants/tivarch-installer.service "
                "/mnt/etc/systemd/system/tivarch-installer.service || true",
                "Disabling live installer daemon on target"
            )
            self.run_cmd("sync", "Flushing data to disk")

            self.current_percent = 100
            self.finished.emit(True, "Installation complete! Rebooting into TiVarch...")
        except Exception as e:
            self.finished.emit(False, str(e))


class InstallerBackend(QObject):
    wifiListChanged = Signal()
    disksChanged = Signal()
    keymapsChanged = Signal()
    timezonesChanged = Signal()
    networkStatusChanged = Signal()
    installProgressChanged = Signal(int, str)
    installFinishedChanged = Signal(bool, str)
    hasKeyboardChanged = Signal()

    def __init__(self):
        super().__init__()
        self._wifi_list = []
        self._disks = []
        self._keymaps = ["us", "trq", "de", "fr", "es", "uk", "it", "ru"]
        self._timezones = [
            "Europe/Istanbul",
            "UTC",
            "Europe/London",
            "Europe/Berlin",
            "America/New_York",
            "America/Los_Angeles",
            "Asia/Tokyo"
        ]
        self._net_type = "Checking..."
        self._net_details = "Probing network devices..."
        self._detected_timezone = "UTC"
        self._worker = None

        self.updateNetworkStatus()
        self.scanDisks()

    @Property(str, notify=networkStatusChanged)
    def netType(self):
        return self._net_type

    @Property(str, notify=networkStatusChanged)
    def netDetails(self):
        return self._net_details

    @Property(str, notify=networkStatusChanged)
    def detectedTimezone(self):
        return self._detected_timezone

    @Property(list, notify=wifiListChanged)
    def wifiList(self):
        return self._wifi_list

    @Property(list, notify=disksChanged)
    def disks(self):
        return self._disks

    @Property(list, notify=keymapsChanged)
    def keymaps(self):
        return self._keymaps

    @Property(list, notify=timezonesChanged)
    def timezones(self):
        return self._timezones

    @Property(bool, notify=hasKeyboardChanged)
    def hasKeyboard(self):
        try:
            with open("/proc/bus/input/devices", "r") as f:
                content = f.read().lower()
                return "handlers=sysrq kbd" in content or "keyboard" in content
        except Exception:
            return False

    @Slot()
    def updateNetworkStatus(self):
        """Identifies Ethernet/Wi-Fi connection status and resolves online timezone if connected."""
        try:
            res = subprocess.check_output(
                ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"],
                text=True,
                stderr=subprocess.DEVNULL
            )
            has_eth = False
            has_wifi = False
            active_name = ""

            for line in res.strip().split("\n"):
                if not line or ":" not in line:
                    continue
                parts = line.split(":")
                if len(parts) >= 4:
                    dev, dev_type, state, conn = parts[0], parts[1], parts[2], parts[3]
                    if state == "connected":
                        if dev_type == "ethernet":
                            has_eth = True
                            active_name = conn or dev
                        elif dev_type == "wifi":
                            has_wifi = True
                            active_name = conn or dev

            if has_eth:
                self._net_type = "Ethernet"
                self._net_details = f"Connected ({active_name})"
            elif has_wifi:
                self._net_type = "Wi-Fi"
                self._net_details = f"Connected ({active_name})"
            else:
                self._net_type = "Offline"
                self._net_details = "Not connected to the internet"

            # Check online timezone if active
            if self._net_type != "Offline":
                try:
                    req = urllib.request.Request("https://ipapi.co/timezone/", headers={"User-Agent": "TiVarch-Installer"})
                    with urllib.request.urlopen(req, timeout=2.5) as resp:
                        tz = resp.read().decode().strip()
                        if "/" in tz:
                            self._detected_timezone = tz
                            if tz not in self._timezones:
                                self._timezones.insert(0, tz)
                                self.timezonesChanged.emit()
                except Exception:
                    pass

            self.networkStatusChanged.emit()
        except Exception:
            self._net_type = "Offline"
            self._net_details = "NetworkManager inactive"
            self.networkStatusChanged.emit()

    @Slot()
    def scanWifi(self):
        try:
            cmd = ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
            raw = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
            results = []
            seen = set()
            for line in raw.strip().split("\n"):
                if not line:
                    continue
                parts = line.split(":")
                if len(parts) >= 3 and parts[0] and parts[0] not in seen:
                    seen.add(parts[0])
                    results.append({
                        "ssid": parts[0],
                        "signal": int(parts[1]) if parts[1].isdigit() else 50,
                        "security": parts[2] if parts[2] else "Open"
                    })
            self._wifi_list = results
            self.wifiListChanged.emit()
        except Exception:
            self._wifi_list = []
            self.wifiListChanged.emit()

    @Slot(str, str, result=bool)
    def connectWifi(self, ssid, password):
        try:
            if password:
                cmd = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
            else:
                cmd = ["nmcli", "dev", "wifi", "connect", ssid]
            res = subprocess.run(cmd, capture_output=True, text=True)
            self.updateNetworkStatus()
            return res.returncode == 0
        except Exception:
            return False

    @Slot()
    def scanDisks(self):
        try:
            out = subprocess.check_output(
                ["lsblk", "-J", "-b", "-o", "NAME,SIZE,MODEL,TYPE,TRAN,RM,RO"],
                text=True,
                stderr=subprocess.DEVNULL
            )
            data = json.loads(out)
            disk_list = []
            for block in data.get("blockdevices", []):
                if block.get("type") == "disk":
                    # Ignore read-only media and optical drives
                    if block.get("ro") is True or block.get("rm") is True:
                        continue
                    # Ignore USB live-media or airootfs drives
                    if block.get("tran") == "usb" or "airootfs" in block.get("name", ""):
                        continue
                    size_gb = round(int(block.get("size", 0)) / (1024**3), 1)
                    if size_gb >= 4:  # 4GB minimum installation threshold
                        disk_list.append({
                            "device": f"/dev/{block.get('name')}",
                            "name": f"/dev/{block.get('name')}",
                            "size": f"{size_gb} GB",
                            "model": block.get("model") or "Internal Storage Drive"
                        })
            self._disks = disk_list
            self.disksChanged.emit()
        except Exception:
            self._disks = []
            self.disksChanged.emit()

    @Slot(str)
    def setKeymap(self, keymap):
        """Applies layout to Console TTY, X11/Wayland settings, and active Cage compositor."""
        try:
            subprocess.run(["loadkeys", keymap], capture_output=True)
            xkb_layout = {"trq": "tr", "uk": "gb"}.get(keymap, keymap)
            os.environ["XKB_DEFAULT_LAYOUT"] = xkb_layout
            subprocess.run(["localectl", "set-x11-keymap", xkb_layout], capture_output=True)
            # Runtime compositor keymap switch if wlrctl is available
            subprocess.run(["wlrctl", "keyboard", "layout", xkb_layout], capture_output=True)
        except Exception:
            pass

    @Slot(str)
    def applyTimezoneAndSync(self, timezone):
        try:
            subprocess.run(["timedatectl", "set-timezone", timezone], capture_output=True)
            subprocess.run(["timedatectl", "set-ntp", "true"], capture_output=True)
        except Exception:
            pass

    @Slot()
    def openDebugTerminal(self):
        """Spawns an emergency debug terminal on top of the UI."""
        for term in ["foot", "alacritty", "kitty", "weston-terminal", "xterm"]:
            if subprocess.run(f"which {term}", shell=True, capture_output=True).returncode == 0:
                subprocess.Popen([term])
                return

    @Slot(str, str, str, str, str, str, bool)
    def startInstall(self, target_disk, timezone, keymap, hostname, username, password, make_root):
        self._worker = InstallWorker(target_disk, timezone, keymap, hostname, username, password, make_root)
        self._worker.progress.connect(self.installProgressChanged.emit)
        self._worker.finished.connect(self.installFinishedChanged.emit)
        self._worker.start()

    @Slot()
    def rebootSystem(self):
        subprocess.run(["reboot"])


def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    backend = InstallerBackend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_file = os.path.join(os.path.dirname(__file__), "qml/Main.qml")
    engine.load(qml_file)

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()