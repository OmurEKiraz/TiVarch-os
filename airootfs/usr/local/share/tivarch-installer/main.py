#!/usr/bin/env python3
import sys
import os
import subprocess
import shutil
import re
import time
import json
from PySide6.QtCore import QObject, Signal, Slot, Property, QThread
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

ANSI_REGEX = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

class NativeInstallerRunner(QThread):
    progressUpdate = Signal(int, str)
    finished = Signal(bool, str)

    def __init__(self, target_disk, timezone, keymap, hostname, username, password):
        super().__init__()
        self.target_disk = target_disk
        self.timezone = timezone
        self.keymap = keymap
        self.hostname = hostname
        self.username = username
        self.password = password
        self.is_uefi = os.path.exists("/sys/firmware/efi")

    def _run_cmd(self, cmd, err_msg="Command failed"):
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if res.returncode != 0:
            raise RuntimeError(f"{err_msg}:\n{res.stderr.strip()}")
        return res.stdout

    def run(self):
        try:
            self.progressUpdate.emit(5, "Preparing target disk and unmounting...")
            subprocess.run(["umount", "-R", "/mnt"], stderr=subprocess.DEVNULL)
            subprocess.run(["swapoff", "-a"], stderr=subprocess.DEVNULL)

            subprocess.run(["dd", "if=/dev/zero", f"of={self.target_disk}", "bs=1M", "count=10", "status=none"])

            # 1. Partitioning
            self.progressUpdate.emit(10, f"Creating {'GPT (UEFI)' if self.is_uefi else 'MBR (BIOS)'} partition table...")
            disk = self.target_disk
            sep = "p" if (disk[-1].isdigit() or "nvme" in disk or "mmcblk" in disk) else ""

            if self.is_uefi:
                esp_part = f"{disk}{sep}1"
                root_part = f"{disk}{sep}2"
                self._run_cmd(["parted", "-s", disk, "mklabel", "gpt"], "Failed to create GPT label")
                self._run_cmd(["parted", "-s", disk, "mkpart", "ESP", "fat32", "1MiB", "513MiB"], "Failed to create ESP")
                self._run_cmd(["parted", "-s", disk, "set", "1", "esp", "on"], "Failed to set ESP flag")
                self._run_cmd(["parted", "-s", disk, "mkpart", "primary", "ext4", "513MiB", "100%"], "Failed to create root partition")
            else:
                esp_part = None
                root_part = f"{disk}{sep}1"
                self._run_cmd(["parted", "-s", disk, "mklabel", "msdos"], "Failed to create MBR label")
                self._run_cmd(["parted", "-s", disk, "mkpart", "primary", "ext4", "1MiB", "100%"], "Failed to create root partition")
                self._run_cmd(["parted", "-s", disk, "set", "1", "boot", "on"], "Failed to set boot flag")

            time.sleep(1)
            subprocess.run(["partprobe", disk])

            # 2. Formatting & Mounting
            self.progressUpdate.emit(18, "Formatting filesystems...")
            if self.is_uefi:
                self._run_cmd(["mkfs.fat", "-F32", esp_part], "Failed to format ESP (fat32)")
            self._run_cmd(["mkfs.ext4", "-F", root_part], "Failed to format root (ext4)")

            self.progressUpdate.emit(25, "Mounting target structure to /mnt...")
            os.makedirs("/mnt", exist_ok=True)
            self._run_cmd(["mount", root_part, "/mnt"], "Failed to mount root partition")

            if self.is_uefi:
                os.makedirs("/mnt/boot", exist_ok=True)
                self._run_cmd(["mount", esp_part, "/mnt/boot"], "Failed to mount boot partition")

            # 3. Pacstrap Base System
            self.progressUpdate.emit(30, "Bootstrapping TiVarch base packages...")
            pkgs = [
                # --- System & Kernel ---
                "base",
                "linux-lts",
                "linux-firmware",
                "mkinitcpio",
                "amd-ucode",
                "intel-ucode",
                "sudo",
                "bash-completion",
                "nano",

                # --- Graphics & Display Server ---
                "mesa",
                "xorg-server",
                "xorg-xwayland",
                "qt6-wayland",
                "sddm",

                # --- Bigscreen Core & Dependencies ---
                "plasma-bigscreen",
                "plasma-workspace",
                "plasma-nano",
                "powerdevil",      # Fixes batterymonitor QML error
                "plasma-pa",        # Fixes org.kde.plasma.private.volume
                "plasma-nm",        # Fixes org.kde.plasma.networkmanagement
                "kde-cli-tools",
                "libcec",           # TV remote HDMI-CEC integration

                # --- Audio Stack ---
                "pipewire",
                "pipewire-pulse",
                "wireplumber",

                # --- Network & Boot ---
                "networkmanager",
                "grub"
            ]
            if self.is_uefi:
                pkgs.append("efibootmgr")

            pacstrap_cmd = ["pacstrap", "-K", "/mnt"] + pkgs
            proc = subprocess.Popen(
                pacstrap_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            progress = 30
            for raw_line in proc.stdout:
                clean_line = ANSI_REGEX.sub('', raw_line).strip()
                if clean_line:
                    if "(" in clean_line and "/" in clean_line and ")" in clean_line:
                        progress = min(progress + 1, 75)
                    self.progressUpdate.emit(progress, clean_line[:75])

            proc.wait()
            if proc.returncode != 0:
                raise RuntimeError("pacstrap failed while downloading/installing packages.")

            # 4. Generate FSTAB
            self.progressUpdate.emit(78, "Generating /etc/fstab...")
            fstab_out = self._run_cmd(["genfstab", "-U", "/mnt"], "Failed to generate fstab")
            with open("/mnt/etc/fstab", "a") as f:
                f.write(fstab_out)

            # 5. System Configuration via chroot helper
            self.progressUpdate.emit(82, "Configuring system locale and timezone...")
            self._run_cmd(["arch-chroot", "/mnt", "ln", "-sf", f"/usr/share/zoneinfo/{self.timezone}", "/etc/localtime"])
            self._run_cmd(["arch-chroot", "/mnt", "hwclock", "--systohc"])

            with open("/mnt/etc/locale.gen", "w") as f:
                f.write("en_US.UTF-8 UTF-8\n")
            self._run_cmd(["arch-chroot", "/mnt", "locale-gen"])

            with open("/mnt/etc/locale.conf", "w") as f:
                f.write("LANG=en_US.UTF-8\n")

            with open("/mnt/etc/vconsole.conf", "w") as f:
                f.write(f"KEYMAP={self.keymap}\n")

            with open("/mnt/etc/hostname", "w") as f:
                f.write(f"{self.hostname}\n")

            with open("/mnt/etc/hosts", "w") as f:
                f.write(f"127.0.0.1   localhost\n::1         localhost\n127.0.1.1   {self.hostname}.localdomain {self.hostname}\n")

            # 6. User Setup & Passwordless Sudo
            self.progressUpdate.emit(87, f"Setting up 10-foot user profile for {self.username}...")
            self._run_cmd(["arch-chroot", "/mnt", "useradd", "-m", "-G", "wheel,audio,video,input,storage", "-s", "/bin/bash", self.username])

            chpasswd_input = f"{self.username}:{self.password}\nroot:{self.password}\n"
            p = subprocess.Popen(["arch-chroot", "/mnt", "chpasswd"], stdin=subprocess.PIPE, text=True)
            p.communicate(input=chpasswd_input)

            os.makedirs("/mnt/etc/sudoers.d", exist_ok=True)
            with open("/mnt/etc/sudoers.d/00_wheel_nopasswd", "w") as f:
                f.write("%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n")
            os.chmod("/mnt/etc/sudoers.d/00_wheel_nopasswd", 0o440)

            # 7. SDDM Auto-login straight to Plasma Bigscreen
            self.progressUpdate.emit(90, "Enabling SDDM auto-login to Plasma Bigscreen...")
            os.makedirs("/mnt/etc/sddm.conf.d", exist_ok=True)
            with open("/mnt/etc/sddm.conf.d/autologin.conf", "w") as f:
                f.write(
                    "[Autologin]\n"
                    f"User={self.username}\n"
                    "Session=plasma-bigscreen-wayland\n"
                    "Relogin=false\n"
                )

            self._run_cmd(["arch-chroot", "/mnt", "systemctl", "enable", "NetworkManager", "sddm"])

            # 8. Bootloader Installation (GRUB)
            self.progressUpdate.emit(93, f"Installing GRUB bootloader ({'UEFI' if self.is_uefi else 'BIOS'})...")
            if self.is_uefi:
                self._run_cmd([
                    "arch-chroot", "/mnt", "grub-install",
                    "--target=x86_64-efi",
                    "--efi-directory=/boot",
                    "--bootloader-id=TiVarch",
                    "--removable"
                ], "Failed to install UEFI GRUB")
            else:
                self._run_cmd([
                    "arch-chroot", "/mnt", "grub-install",
                    "--target=i386-pc",
                    disk
                ], "Failed to install BIOS GRUB")

            self.progressUpdate.emit(97, "Generating GRUB configuration...")
            self._run_cmd(["arch-chroot", "/mnt", "grub-mkconfig", "-o", "/boot/grub/grub.cfg"], "Failed to generate grub.cfg")

            self.progressUpdate.emit(99, "Synchronizing filesystem buffers...")
            subprocess.run(["sync"])
            subprocess.run(["umount", "-R", "/mnt"])

            self.progressUpdate.emit(100, "Installation Complete!")
            self.finished.emit(True, "TiVarch OS was installed successfully. You can now reboot into your TV interface!")

        except Exception as e:
            subprocess.run(["umount", "-R", "/mnt"], stderr=subprocess.DEVNULL)
            self.finished.emit(False, str(e))


class DiskScannerWorker(QThread):
    disksScanned = Signal(list)

    def run(self):
        try:
            live_devices = set()
            if os.path.exists("/proc/mounts"):
                with open("/proc/mounts", "r") as f:
                    for line in f:
                        parts = line.split()
                        if len(parts) >= 2:
                            mnt = parts[1]
                            dev = parts[0]
                            if "/run/archiso" in mnt and dev.startswith("/dev/"):
                                real_dev = os.path.realpath(dev)
                                parent = re.sub(r'p?\d+$', '', real_dev)
                                live_devices.add(parent)
                                live_devices.add(real_dev)

            out = subprocess.check_output(
                ["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,MODEL,TYPE,RO"],
                text=True,
                stderr=subprocess.DEVNULL
            )
            data = json.loads(out)
            disk_list = []

            for block in data.get("blockdevices", []):
                if block.get("type") != "disk":
                    continue
                if block.get("ro") in [True, 1, "1"]:
                    continue

                dev_path = block.get("path") or f"/dev/{block.get('name')}"
                real_dev = os.path.realpath(dev_path)

                if real_dev in live_devices:
                    continue

                size_bytes = int(block.get("size", 0) or 0)
                size_gb = round(size_bytes / (1024**3), 1)

                if size_gb >= 8:
                    model_str = block.get("model")
                    display_name = model_str.strip() if model_str else "VirtIO / System Disk"
                    disk_list.append({
                        "device": dev_path,
                        "name": f"{dev_path} ({size_gb} GB)",
                        "size": f"{size_gb} GB",
                        "model": display_name
                    })

            self.disksScanned.emit(disk_list)
        except Exception:
            self.disksScanned.emit([])


class WifiScannerWorker(QThread):
    wifiScanned = Signal(list)

    def run(self):
        try:
            raw = subprocess.check_output(
                ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"],
                text=True,
                stderr=subprocess.DEVNULL
            )
            results = []
            seen = set()
            for line in raw.strip().split("\n"):
                parts = line.split(":")
                if len(parts) >= 3 and parts[0] and parts[0] not in seen:
                    seen.add(parts[0])
                    results.append({
                        "ssid": parts[0],
                        "signal": int(parts[1]) if parts[1].isdigit() else 50,
                        "security": parts[2] or "Open"
                    })
            self.wifiScanned.emit(results)
        except Exception:
            self.wifiScanned.emit([])


class NetworkStatusWorker(QThread):
    statusReady = Signal(str, str)

    def run(self):
        try:
            res = subprocess.check_output(
                ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"],
                text=True,
                stderr=subprocess.DEVNULL
            )
            for line in res.strip().split("\n"):
                parts = line.split(":")
                if len(parts) >= 3 and parts[1] == "connected":
                    self.statusReady.emit(parts[0].capitalize(), parts[2])
                    return
            self.statusReady.emit("Offline", "Not connected")
        except Exception:
            self.statusReady.emit("Offline", "NetworkManager unreachable")


class InstallerBackend(QObject):
    disksChanged = Signal()
    wifiListChanged = Signal()
    netStatusChanged = Signal()
    progressChanged = Signal(int, str)
    installFinished = Signal(bool, str)

    def __init__(self):
        super().__init__()
        self._disks = []
        self._wifi_list = []
        self._net_type = "Offline"
        self._net_details = "Checking..."
        self._keymaps = ["us", "trq", "de", "fr", "es", "uk", "it"]
        self._timezones = ["UTC", "Europe/Istanbul", "Europe/London", "Europe/Berlin", "America/New_York"]

        self._runner = None
        self._disk_scanner = None
        self._wifi_scanner = None
        self._net_worker = None

        self.scanDisks()
        self.updateNetworkStatus()

    @Property(list, notify=disksChanged)
    def disks(self):
        return self._disks

    @Property(list, notify=wifiListChanged)
    def wifiList(self):
        return self._wifi_list

    @Property(str, notify=netStatusChanged)
    def netType(self):
        return self._net_type

    @Property(str, notify=netStatusChanged)
    def netDetails(self):
        return self._net_details

    @Property(list, constant=True)
    def keymaps(self):
        return self._keymaps

    @Property(list, constant=True)
    def timezones(self):
        return self._timezones

    @Slot()
    def scanDisks(self):
        if self._disk_scanner and self._disk_scanner.isRunning():
            return
        self._disk_scanner = DiskScannerWorker()
        self._disk_scanner.disksScanned.connect(self._onDisksScanned)
        self._disk_scanner.start()

    def _onDisksScanned(self, disks):
        self._disks = disks
        self.disksChanged.emit()

    @Slot()
    def updateNetworkStatus(self):
        if self._net_worker and self._net_worker.isRunning():
            return
        self._net_worker = NetworkStatusWorker()
        self._net_worker.statusReady.connect(self._onNetStatusReady)
        self._net_worker.start()

    def _onNetStatusReady(self, net_type, net_details):
        self._net_type = net_type
        self._net_details = net_details
        self.netStatusChanged.emit()

    @Slot()
    def scanWifi(self):
        if self._wifi_scanner and self._wifi_scanner.isRunning():
            return
        self._wifi_scanner = WifiScannerWorker()
        self._wifi_scanner.wifiScanned.connect(self._onWifiScanned)
        self._wifi_scanner.start()

    def _onWifiScanned(self, wifi_list):
        self._wifi_list = wifi_list
        self.wifiListChanged.emit()

    @Slot(str, str)
    def connectWifi(self, ssid, password):
        cmd = ["nmcli", "dev", "wifi", "connect", ssid]
        if password:
            cmd.extend(["password", password])
        subprocess.Popen(cmd)
        self.updateNetworkStatus()

    @Slot(str)
    def setKeymap(self, keymap):
        subprocess.Popen(["loadkeys", keymap])
        xkb = {"trq": "tr", "uk": "gb"}.get(keymap, keymap)
        subprocess.Popen(["localectl", "set-x11-keymap", xkb])

    @Slot(str, str, str, str, str, str)
    def startInstallation(self, target_disk, timezone, keymap, hostname, username, password):
        clean_host = re.sub(r'[^a-zA-Z0-9-]', '', hostname).strip('-') or "tivarch"
        clean_user = re.sub(r'[^a-z0-9_-]', '', username.lower()).strip('-') or "tivuser"
        clean_pass = password if password else "tivarch"

        self._runner = NativeInstallerRunner(
            target_disk=target_disk,
            timezone=timezone,
            keymap=keymap,
            hostname=clean_host,
            username=clean_user,
            password=clean_pass
        )
        self._runner.progressUpdate.connect(self.progressChanged.emit)
        self._runner.finished.connect(self.installFinished.emit)
        self._runner.start()

    @Slot()
    def reboot(self):
        subprocess.run(["systemctl", "reboot"])


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