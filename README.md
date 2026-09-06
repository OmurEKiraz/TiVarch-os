# TiVarch OS

> An Arch Linux-based, lightweight Linux distro for custom TV boxes, mini-PCs, and older hardware.

---

## Overview

TiVarch transforms standard x86_64 PCs, mini-PCs, and media boxes into a dedicated TV console. Powered by an optimized Arch Linux core and running Plasma Bigscreen over Wayland, it provides a zero-login, controller-friendly interface straight to your display.

---

## Key Features

- Living Room Native: Built around Plasma Bigscreen, Wayland, and PipeWire for low-latency media playback and HDMI audio passthrough.
- Zero-Friction Startup: Instant SDDM autologin directly into the Bigscreen Wayland session with passwordless administrative execution for maintenance.
- TV-Optimized QML Setup: High-contrast, gamepad- and remote-navigable setup wizard with live network diagnostics, disk partitioning safety guards, and animated deployment progress.
- Dual Boot Support: Seamless EFI system partition setup and BIOS fallback via GRUB.
- HDMI-CEC & Remote Ready: Built-in support for TV remote controls via libcec and modern input layers.

---

## Architecture & Tech Stack

| Component | Implementation |
| :--- | :--- |
| Base System | Arch Linux (LTS Kernel) |
| Shell & UI | KDE Plasma Bigscreen (Wayland) |
| Display Manager | SDDM (Wayland Autologin) |
| Audio Server | PipeWire + WirePlumber (pipewire-pulse) |
| Live Environment | Custom archiso with Zstandard (zstd) compression |
| Installer Engine | Python 3 + PySide6 / QML |
| Network Backend | NetworkManager |

---

## Building the ISO

### Prerequisites

Ensure you are running an Arch-based system with the required packages:

- sudo pacman -S archiso qemu-desktop ovmf git

### Build Instructions

1. Clone the repository:
   - git clone https://github.com/OmurEKiraz/TiVarch-os.git
   
   - cd TiVarch-os

3. Generate the bootable ISO:

   - sudo mkarchiso -v -w /tmp/archiso-tmp -o ./out .

The compiled ISO image will be placed in the ./out/ directory.

---

## Roadmap

- [D] Custom native Python/QML installation pipeline
- [D] Plasma Bigscreen Wayland session with autologin
- [C] Full audio stack and network configuration integration
- [?] First-boot Out-of-Box Experience (OOBE) with QR code smartphone remote pairing
- [?] Smartphone virtual controller daemon via /dev/uinput
- [?] Dedicated kiosk runners (YouTube, Netflix, Prime) with Smart TV user-agent spoofing
- [?] Blu-ray playback support and other stuff

* (D = done, C = Current, ? = Someday)
---

## Contributing & Project Status

This is an experimental side project. I'm still learning the ins and outs of maintaining both a full Linux distribution and a collaborative GitHub repository. The custom installer and system scripts are written like about 40-50% by me and the rest with AI so any help is appreciated.

Feedback, bug reports, ideas, and pull requests are very welcome!

---

## License

TiVarch is free and open-source software licensed under the GNU General Public License v3.0 (LICENSE).
