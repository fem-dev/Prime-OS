# Prime-OS

**Prime-OS** is an early, community-built gaming Linux project based on Arch Linux and the [Hyprland](https://hyprland.org/) Wayland compositor. The current milestone is a bootable **live ISO prototype**, not yet a finished installer or a production-ready operating system. [راهنمای فارسی](README.fa.md)

The setup launcher supports Windows, Linux and macOS. Windows uses the native Segoe UI font when available and stores app data under `%LOCALAPPDATA%\\Prime-OS`, with preferences under `%APPDATA%\\Prime-OS`. This opens the Windows setup preview; it does not replace Windows with Arch/Hyprland.

> Game performance and hardware compatibility depend on your GPU, drivers, game, and hardware. They cannot be guaranteed to be lag-free. Test the ISO in a virtual machine first; use a spare USB drive if you test on physical hardware.

## What is included in the prototype

- Arch Linux live environment, built using the official `archiso` releng profile.
- Hyprland, Waybar, Wofi, Kitty, NetworkManager and PipeWire.
- A cross-platform setup wizard for Windows, Linux and macOS that uses a system font fallback and loads the supplied `you.py` artwork module without executing it.
- Steam, Lutris and Mesa/Vulkan gaming packages.
- A minimal first-boot graphical session as a regular `prime` user.
- A convenience wrapper that creates `out/os.iso`.

This image is for preview and testing. It does **not** currently install Prime-OS onto a disk. Secure Boot, an install wizard, hardware-specific performance tuning and automated hardware testing are not implemented yet. The package list contains common graphics drivers, but one ISO cannot include every proprietary GPU driver; NVIDIA open-kernel-module support also depends on the graphics card model.

## Build the ISO

The builder uses Docker to run Arch Linux in an isolated container; it does not require installing Linux on the host. Docker must be installed and running, and the build needs an internet connection and several gigabytes of free space.

```bash
git clone https://github.com/fem-dev/Prime-OS.git
cd Prime-OS
docker run --rm --privileged \
  -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" \
  -w /work \
  archlinux:latest \
  bash -lc 'pacman -Syu --noconfirm archiso && PRIME_OS_BUILD_CONTAINER=1 bash ./build.sh'
```

On success, the image is created at `out/os.iso`. The project does not currently publish a prebuilt ISO. Do not run `build.sh` with `sudo` directly on the host.

### Build and run on Windows

Windows cannot build a bootable Arch ISO directly. Install **WSL2** and an Arch Linux distribution in WSL, then build with `sudo ./build.sh`. For best reliability, build in an Arch Linux VM or on a Linux machine.

To run a built ISO in a disposable QEMU virtual machine from **Git Bash**, install QEMU for Windows and run:

```bash
./run-windows.sh
```

The script expects `out/os.iso`. An alternate ISO path can be passed as `./run-windows.sh /path/to/os.iso`. It boots the image read-only and does not modify Windows disks. If QEMU's WHPX accelerator is unavailable, change the final QEMU acceleration option from `-accel whpx:tcg` to `-accel tcg`.

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
