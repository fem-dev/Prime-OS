# Prime-OS

**Prime-OS** is an early, community-built gaming Linux project based on Arch Linux and the [Hyprland](https://hyprland.org/) Wayland compositor. The current milestone is a bootable **live ISO prototype**, not yet a finished installer or a production-ready operating system. [راهنمای فارسی](README.fa.md)

> Game performance and hardware compatibility depend on your GPU, drivers, game, and hardware. They cannot be guaranteed to be lag-free. Test the ISO in a virtual machine first; use a spare USB drive if you test on physical hardware.

## What is included in the prototype

- Arch Linux live environment, built using the official `archiso` releng profile.
- Hyprland, Waybar, Wofi, Kitty, NetworkManager and PipeWire.
- Steam, Lutris and Mesa/Vulkan gaming packages.
- A minimal first-boot graphical session as a regular `prime` user.
- A convenience wrapper that creates `out/os.iso`.

This image is for preview and testing. It does **not** currently install Prime-OS onto a disk. Secure Boot, an install wizard, hardware-specific performance tuning and automated hardware testing are not implemented yet. The package list contains common graphics drivers, but one ISO cannot include every proprietary GPU driver; NVIDIA open-kernel-module support also depends on the graphics card model.

## Fast start on Linux

The image builder currently requires a native Arch Linux build environment with `archiso` installed. A recommended beginner path is to install Arch Linux in a virtual machine first.

```bash
git clone https://github.com/fem-dev/Prime-OS.git
cd Prime-OS
sudo pacman -Syu --needed archiso
sudo ./build.sh
```

The finished image is `out/os.iso`. The first build needs an internet connection and downloads many Arch packages. A few gigabytes of free disk space may be needed in addition to the working directory.

### Build on Windows

Windows cannot build a bootable Arch ISO directly. Install **WSL2** and an Arch Linux distribution in WSL, then open the project folder from within that Arch environment and run the Linux commands above. For best build reliability and speed, build in Arch Linux on a VM or a Linux machine. `build.ps1` is only a convenience launcher when WSL already has a working Arch environment and can access the project folder.

## Try the ISO

Boot `out/os.iso` in a UEFI virtual machine (for example, QEMU or VirtualBox), or write it to a spare USB drive with an image-writing tool. Booting an ISO does **not** install it to your computer. Never flash a drive that contains files you need.

In Hyprland, press:

- `Super + Enter` — terminal
- `Super + D` — application launcher
- `Super + G` — Steam
- `Super + B` — browser
- `Super + N` — network settings
- `Super + M` — exit Hyprland

## Build script options

```bash
sudo ./build.sh
```

`build.sh` validates that it is running as root on Arch Linux, copies the installed official `archiso` releng profile into `.build/profile`, enables the official multilib repository in that temporary profile for Steam, and writes build output to `out/`. Generated work files and ISO images are ignored by Git. The Arch profile is copied from the local `archiso` package at build time so its boot files and configuration stay in step with the installed version.

## Project status

This is the starting point, not a claim that a complete gaming OS already exists. Next milestones: build and boot the first ISO, fix startup/package issues on real test hardware, design an installer, then add tested gaming profiles and update/recovery flows. Contributions and hardware test reports are welcome.
