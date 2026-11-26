# Prime-OS

**A small bootable installer that asks what you want, then installs only that.**

Prime-OS is an Arch Linux and Hyprland setup built around one rule: the image you
download is an *installer*, not a desktop. It is a few hundred megabytes, it
contains no applications, and when it starts it asks which components you want.
Everything else is fetched from the Arch mirrors during installation, one chosen
component at a time.

No image files, no wallpaper, no logo assets: the session paints itself in solid
colours defined in [`branding/palette.json`](branding/palette.json).

---

## How it works

1. **Boot the image.** The first console autologins as root and starts the setup
   program; every other console stays a normal shell.
2. **It checks the machine and the network**, and tells you plainly when it
   cannot reach an Arch mirror.
3. **You pick the disk.** It always asks you to type `ERASE` back, and it refuses
   to touch a disk that still has mounted filesystems.
4. **You tick the components** you want — desktop, a graphics driver, fonts,
   applications. Each component is one file; nothing is installed that you did
   not tick, and the screen shows the download size before you commit.
5. **It installs**: `pacstrap` writes only the packages of the chosen components,
   then the overlay puts the Prime-OS session on the new system, the boot loader
   is installed and the user account is created.
6. **Reboot.** The installed machine contains what you chose, and nothing else.

What the image deliberately does *not* contain: a desktop, applications,
drivers, or a full copy of the system. That is the whole point — the nine
components you pick beat one image that guesses.

## Components

One file per component in [`components/`](components): a `.list` of Arch package
names and a `.desc` with its title and one sentence. Add a component by adding
those two files — no code change.

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

## Install

There are three ways in, and they are not interchangeable by operating system.
Pick the row that describes your machine.

| What you want | Your machine | Where |
| --- | --- | --- |
| Install Prime-OS on the computer you are sitting at | **Linux**, booted from an Arch live session | [Linux: one line](#linux-one-line) |
| Install Prime-OS from a USB stick | **Windows, macOS or Linux** | [Any OS: the setup image](#any-os-the-setup-image) |
| Download the image in a desktop window, then use it yourself | **Windows, macOS or Linux** | [Any OS: the desktop downloader](#any-os-the-desktop-downloader-optional) |

### Linux: one line

**Linux only.** This command downloads the repository, installs the tools the
wizard uses and starts it. It needs an Arch live session — the
[official Arch ISO](https://archlinux.org/download/) or a Prime-OS setup image
booted from USB — and it refuses to run on a normal, installed system, so your
working machine is never partitioned by accident.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh)"
```

A live session logs you in as root, so the line needs no `sudo`; from another
account, put `sudo` in front of the whole line. Keep it in this shape: do **not**
run it as `curl … | bash`. The wizard draws full-screen panels and reads the
keyboard from the console, so a pipe — which replaces the console with the
script — leaves the wizard without a keyboard, and it says so and stops.

Everything after that is a question: the disk (you type `ERASE`), the components,
the account. On a Prime-OS setup image the same command uses the copy already on
the image and skips the download.

`PRIME_OS_REF` selects what to install — any branch, tag or commit. The default
is `main`:

```bash
PRIME_OS_REF=main bash -c "$(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh)"
```

From a normal account the variable has to reach sudo's environment as well:
`PRIME_OS_REF=main sudo -E bash -c "$(curl …)"`.

Wi-Fi is not set up for you: at the live console run `nmtui`, connect, then run
the command again. This path does not exist on Windows or macOS — those machines
have no Arch live session and no `pacman`; use the setup image below.

### Any OS: the setup image

This is the way in from **Windows, macOS and Linux**. You download one file,
check it, write it to a USB stick and boot the machine from that stick. The
wizard on the stick is the same wizard the one-liner starts.

**1. Download.** Take `os.iso` and `os.iso.sha256` from the
[latest release](https://github.com/fem-dev/Prime-OS/releases).

**2. Check the download** — one command per platform, compare with
`os.iso.sha256`:

```bash
# Linux
sha256sum -c os.iso.sha256
```

```bash
# macOS
shasum -a 256 -c os.iso.sha256
```

```powershell
# Windows (PowerShell)
(Get-FileHash .\os.iso -Algorithm SHA256).Hash
Get-Content .\os.iso.sha256
```

**3. Write it to a USB stick.** This erases the stick, not the computer.

```bash
# Linux — /dev/sdX is the stick, check it twice with lsblk
sudo dd if=os.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

```bash
# macOS — diskutil list shows the stick, e.g. disk4; write to the rdisk node
diskutil unmountDisk /dev/disk4
sudo dd if=os.iso of=/dev/rdisk4 bs=4m
```

On **Windows**, use [Rufus](https://rufus.ie) or
[balenaEtcher](https://etcher.balancer.io) and select `os.iso`. If Rufus asks
about ISOHybrid mode, choose **Write in DD image mode**.

**4. Boot it.** Open the firmware boot menu (usually `F12`, `F11` or `Esc` at
power-on), pick the stick, and the setup program starts on the first console.

### Any OS: the desktop downloader (optional)

A small window that downloads `os.iso`, verifies its SHA-256 and keeps it in a
sensible folder. It never writes a USB stick, never repartitions and never
installs the operating system: after it finishes you still write the stick
yourself. Skip it if you already have the file.

```bash
# Linux — needs curl, python3, venv and Tk:
#   Debian/Ubuntu: sudo apt install curl python3 python3-venv python3-tk
#   Arch:          sudo pacman -S curl python tk
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

```bash
# macOS — uses install-mac.sh, not install.sh: install.sh needs sha256sum,
# which macOS does not have. Needs Python 3 from python.org (it includes Tk).
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install-mac.sh)
```

```powershell
# Windows — PowerShell 5.1 or later, no administrator rights.
# Needs Python 3 from python.org with "Add python.exe to PATH" and
# "tcl/tk and IDLE" enabled during setup.
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

If a downloader step fails, it says why and leaves a log in
`%TEMP%\prime-os-install.log` on Windows, printed on screen on Linux and macOS.
If the window cannot open at all, download the release by hand — that path needs
nothing but a browser.

## Build the image yourself

The build needs Arch's `archiso` and root, so it runs in a container **on a Linux
machine with Docker** (not on Windows or macOS directly):

```bash
docker run --rm -it --privileged -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" -w /work archlinux:latest
# inside the container:
pacman -Syu --noconfirm archiso
bash build.sh
```

`out/os.iso` is the installer. GitHub Actions builds and publishes it on every
push to `main` ([`.github/workflows/build-iso.yml`](.github/workflows/build-iso.yml)),
so you do not need a local build to get one.

## Repository layout

| Path | What it is |
| --- | --- |
| [`installer/prime-os-setup`](installer/prime-os-setup) | The program that runs on the setup ISO. |
| [`installer/lib/`](installer/lib) | One file per step: `common`, `network`, `disk`, `components`, `account`, `apply`, `boot`. |
| [`installer/overlay/`](installer/overlay) | What is written onto the *installed* system: Hyprland, waybar, `issue`, `motd`, key list. |
| [`components/`](components) | The per-component package lists the user chooses from. |
| [`profile/`](profile) | The live side of the ISO: `live-packages.list`, autologin, console text. |
| [`build.sh`](build.sh) | Assembles the ISO with `mkarchiso`. |
| [`setup.sh`](setup.sh) | The one-line installer for Linux: fetch this repository and run the wizard. |
| [`install.sh`](install.sh) · [`install-mac.sh`](install-mac.sh) · [`install.ps1`](install.ps1) | The desktop downloader, one per platform, pinned to a commit. |
| [`loader.py`](loader.py) | The downloader window itself, used by all three scripts. |
| [`branding/`](branding) | Palette and the written brand rules. No raster assets. |
| [`DOCS.md`](DOCS.md) | Every known failure, its cause and its fix. |

## On the installed system

| Path | What it is |
| --- | --- |
| `~/.config/hypr/hyprland.conf` | The session: keybinds, borders, colours. |
| `~/.config/waybar/` | The panel. |
| `/etc/prime-os/install.conf` | What this machine was installed with: components, disk, filesystem, date. |
| `/usr/share/prime-os/keys.txt` | The key list, on disk, so `Super+/` works without a network. |

`Super+Enter` opens a terminal, `Super+D` the launcher, `Super+/` that key list.
Root login is locked on installed systems; the account created during setup is in
`wheel` and uses `sudo`.

## Status, honestly

- The image is an **installer**. It has never been through a hardware install by
  a wide audience; treat a first install as experimental and keep a backup.
- The installed system has **no update helper**: it is plain Arch, so `pacman -Syu`
  is the update path.
- Secure Boot is not configured.
- Nothing is tested automatically beyond the build: the wizard has no test suite,
  and CI only checks that the ISO was produced and is the right size.
- Only this English file is authoritative. The other `README.*.md` translations
  describe an older preview and can lag behind.

Licence: MIT. See [`NOTICE.md`](NOTICE.md) for what this project is not.
