# Prime-OS

A small bootable installer for an Arch Linux + Hyprland desktop. What you download
is the **installer**, not a desktop: it asks which components you want, then
installs only those and fetches everything else from the Arch mirrors. No image
files, no wallpaper, no logos — the session paints itself from
[`branding/palette.json`](branding/palette.json).

---

## Install

Read the label above each block: the three routes need different operating
systems and cannot be swapped.

| Your machine | What you get | Route |
| --- | --- | --- |
| **Linux**, booted from an Arch live session | Prime-OS installed on this computer | [1](#1-install-now--linux-only) |
| **Linux, macOS, Windows** | a USB stick that installs Prime-OS | [2](#2-write-the-usb-stick--any-os) |
| **Linux, macOS, Windows** | the image file, downloaded in a window | [3](#3-download-the-image-only--any-os-optional) |

### 1. Install now — Linux only

Boot the [official Arch ISO](https://archlinux.org/download/), or a Prime-OS USB.
For Wi-Fi, run `nmtui` in the live console first. Then this command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh)"
```

- A live session is already root; from a normal account, put `sudo` in front of
  the whole line.
- Keep the shape. `curl … | bash` does not work: the pipe replaces the console
  and the wizard needs the console keyboard. It says so and stops.
- Any branch, tag or commit instead of `main`:

```bash
PRIME_OS_REF=main bash -c "$(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh)"
```

It refuses to run on an installed system, so a working machine's disk is safe.
This route does not exist on Windows or macOS: no Arch live session, no `pacman`.

### 2. Write the USB stick — any OS

**Linux**

```bash
cd ~/Downloads
curl -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso
curl -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso.sha256
sha256sum -c os.iso.sha256
lsblk                       # find the stick, e.g. /dev/sdb — check it twice
sudo dd if=os.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**macOS**

```bash
cd ~/Downloads
curl -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso
curl -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso.sha256
shasum -a 256 -c os.iso.sha256
diskutil list               # find the stick, e.g. disk4
diskutil unmountDisk /dev/disk4
sudo dd if=os.iso of=/dev/rdisk4 bs=4m
```

**Windows** — PowerShell, no administrator rights. `curl.exe` is part of Windows
10 (1803 and later) and Windows 11, and it does not inherit PowerShell 5.1's TLS
1.0 problem:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'        # the progress bar makes downloads crawl

New-Item -ItemType Directory -Force "$HOME\Downloads" | Out-Null
cd $HOME\Downloads
curl.exe -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso
curl.exe -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso.sha256

$want = ((Get-Content .\os.iso.sha256) -split '\s+')[0].ToUpper()
(Get-FileHash .\os.iso -Algorithm SHA256).Hash -eq $want     # prints True
```

On Windows older than 10 1803 there is no `curl.exe`: keep the first two lines
and download with `irm <url> -OutFile <file>` instead. Writing the stick is the
only step without a command:
open [Rufus](https://rufus.ie) or [balenaEtcher](https://etcher.balancer.io),
select `os.iso`, and if Rufus asks about ISOHybrid mode choose **DD image mode**.

Then boot the machine from the stick (firmware boot menu: usually `F12`, `F11` or
`Esc` at power-on); the installer starts on the first console.

### 3. Download the image only — any OS, optional

A window that downloads `os.iso`, checks its SHA-256 and saves it. It writes no
USB stick and installs nothing: route 2 still does the writing.

**Linux** — needs `curl`, `python3`, `venv` and Tk:

```bash
sudo apt install curl python3 python3-venv python3-tk   # Debian, Ubuntu
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

**macOS** — `install-mac.sh`, not `install.sh`, which needs `sha256sum`. Needs
Python 3 from python.org (it brings Tk):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install-mac.sh)
```

**Windows** — PowerShell 5.1+, Python 3 from python.org with *Add python.exe to
PATH* and *tcl/tk and IDLE*:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

A failing step says why and leaves a log: `%TEMP%\prime-os-install.log` on
Windows, printed on screen elsewhere. If the window cannot open, use route 2
instead; it needs nothing but `curl` or a browser.

## What the installer asks

1. **The disk.** You type `ERASE` back, and it refuses disks that still have
   mounted filesystems.
2. **The components.** Each is one file in [`components/`](components): a `.list`
   of Arch packages and a `.desc`. Unticked means not installed, and the download
   size is shown before you commit.
3. **The account.** Then `pacstrap` writes the chosen packages, the overlay puts
   the Prime-OS session on the new system, the boot loader goes in, and you
   reboot into what you picked.

## Components

| Component | File | What it installs |
| --- | --- | --- |
| Base system | [`base.list`](components/base.list) | Kernel, pacman, NetworkManager, sudo. Always installed. |
| Hyprland desktop | [`desktop.list`](components/desktop.list) | Hyprland, waybar, wofi, portals, PipeWire, kitty, dunst. |
| Everyday applications | [`apps.list`](components/apps.list) | Firefox, Geany. |
| Latin fonts and emoji | [`fonts.list`](components/fonts.list) | Noto text and emoji faces. |
| Chinese/Japanese/Korean fonts | [`fonts-cjk.list`](components/fonts-cjk.list) | Noto CJK, ~190 MiB. |
| AMD graphics | [`drivers-amd.list`](components/drivers-amd.list) | Mesa, Vulkan, video decoding. |
| Intel graphics | [`drivers-intel.list`](components/drivers-intel.list) | Mesa, Vulkan, media driver. |
| NVIDIA (proprietary) | [`drivers-nvidia.list`](components/drivers-nvidia.list) | `nvidia-open`, settings. Large. |
| 32-bit gaming libraries | [`gaming-32bit.list`](components/gaming-32bit.list) | lib32 Mesa/Vulkan/audio, enables multilib. |

Add a component by adding those two files — no code change.

## Build the image — Linux with Docker

`archiso` needs root, so the build runs in a container:

```bash
docker run --rm -it --privileged -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" -w /work archlinux:latest
# inside the container:
pacman -Syu --noconfirm archiso
bash build.sh
```

`out/os.iso` is the installer. GitHub Actions builds and publishes it on every
push to `main` ([`build-iso.yml`](.github/workflows/build-iso.yml)), so you do not
need a local build to get one.

## Files

| Path | What it is |
| --- | --- |
| [`installer/prime-os-setup`](installer/prime-os-setup) | The program that runs on the setup image. |
| [`installer/lib/`](installer/lib) | One file per step: `common`, `network`, `disk`, `components`, `account`, `apply`, `boot`. |
| [`installer/overlay/`](installer/overlay) | What is written onto the installed system: Hyprland, waybar, `issue`, `motd`, keys. |
| [`components/`](components) | The package lists the user chooses from. |
| [`profile/`](profile) | The live side of the image: `live-packages.list`, autologin, console text. |
| [`build.sh`](build.sh) | Assembles the image with `mkarchiso`. |
| [`setup.sh`](setup.sh) | Route 1: fetch the repository and run the wizard. |
| [`install.sh`](install.sh) · [`install-mac.sh`](install-mac.sh) · [`install.ps1`](install.ps1) | Route 3: the downloader, one per platform, pinned to a commit. |
| [`loader.py`](loader.py) | The downloader window all three scripts run. |
| [`DOCS.md`](DOCS.md) | Every known failure, its cause and its fix. |

## On the installed system

`Super+Enter` opens a terminal, `Super+D` the launcher, `Super+/` the key list.
Root login is locked; the account from setup is in `wheel` and uses `sudo`.
Settings live in `~/.config/hypr/`, `~/.config/waybar/`, and the install record in
`/etc/prime-os/install.conf`.

## Status, honestly

- The image is an **installer**. It has not been through a wide hardware install;
  treat a first install as experimental and keep a backup.
- The installed system is plain Arch: update with `pacman -Syu`. There is no
  update helper, and Secure Boot is not configured.
- Nothing is tested automatically beyond the build; CI only checks that the image
  was produced and is the right size.
- Only this file and [`README.fa.md`](README.fa.md) are current. The other
  `README.*.md` translations describe an older preview and lag behind.

Licence: MIT. See [`NOTICE.md`](NOTICE.md) for what this project is not.
