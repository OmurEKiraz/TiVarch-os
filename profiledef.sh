#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_label="TIVARCH"
iso_publisher="OmurEKiraz <tivarchos@gmail.com>"
iso_application="TiVarch Arch based SmartTV Distro"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"

# Compression Tuning:
# Level 9 gives noticeably smaller ISO sizes than level 3 while maintaining
# rapid decompress speeds on USB drives. -b 1M maximizes squashfs chunk efficiency.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '9' '-b' '1M')

# Multi-threaded Zstandard compression for the bootstrap rootfs
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/tivarch-installer"]="0:0:755"
  ["/usr/local/share/tivarch-installer/main.py"]="0:0:755"
)