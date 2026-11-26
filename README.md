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
drivers, or a full copy of the system. That is the whole point — 40 components
chosen by the user beat one 2.4 GiB image that guesses.

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

One line, from an Arch live session — the [Arch ISO](https://archlinux.org/download/)
or the Prime-OS setup image below:

```bash
curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh | sudo bash
```

It checks the machine, installs the handful of tools the wizard uses, fetches this
repository and starts the wizard. Everything after that is a question: the disk
(you type `ERASE`), the components, the account. From the Prime-OS setup image the
same command uses the copy already on the image and skips the download.

```bash
PRIME_OS_REF=6283bbebd95448b7957a19367f864ff1b6641f54 \
  curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh | sudo -E bash
```

`PRIME_OS_REF` takes any branch, tag or commit; the default is `main`. The
installer refuses to run outside a live session, so a working system is never
partitioned by accident.

### Or boot the setup image

Take `os.iso` from the [latest release](https://github.com/fem-dev/Prime-OS/releases),
check it against the published `sha256`, write it to a USB stick and boot it:

```bash
sha256sum -c os.iso.sha256
sudo dd if=os.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

On Windows, [Rufus](https://rufus.ie) or [balenaEtcher](https://etcher.balancer.io)
write the same file. The image is small enough now that a single download works;
the parts manifest from earlier releases is still understood by the wizard.

### The setup wizard (optional)

The repository also ships a small desktop program that downloads the image,
verifies it and keeps it somewhere sensible. It never writes a USB stick and
never partitions anything.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

It needs Python 3 with Tk, and `curl`. If the window cannot open, download the
release by hand — that path needs nothing but a browser.

## Build the image yourself

The build needs Arch's `archiso` and root, so it runs in a container:

```bash
docker run --rm -it --privileged -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" -w /work archlinux:latest
# inside the container:
pacman -Syu --noconfirm archiso
bash build.sh
```

`out/os.iso` is the installer. GitHub Actions builds and publishes it on every
push to `main` ([`.github/workflows/build-iso.yml`](.github/workflows/build-iso.yml)).

## Repository layout

| Path | What it is |
| --- | --- |
| [`installer/prime-os-setup`](installer/prime-os-setup) | The program that runs on the setup ISO. |
| [`installer/lib/`](installer/lib) | One file per step: `common`, `network`, `disk`, `components`, `account`, `apply`, `boot`. |
| [`installer/overlay/`](installer/overlay) | What is written onto the *installed* system: Hyprland, waybar, `issue`, `motd`, key list. |
| [`components/`](components) | The per-component package lists the user chooses from. |
| [`profile/`](profile) | The live side of the ISO: `live-packages.list`, autologin, console text. |
| [`build.sh`](build.sh) | Assembles the ISO with `mkarchiso`. |
| [`loader.py`](loader.py) | The optional desktop downloader for the image. |
| [`setup.sh`](setup.sh) | The one-line installer: fetch this repository and run the wizard. |
| [`install.sh`](install.sh), [`install-mac.sh`](install-mac.sh), [`install.ps1`](install.ps1) | Install the downloader, pinned to a commit. |
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
- The Persian and other translations of this file can lag behind the English one.

Licence: MIT. See [`NOTICE.md`](NOTICE.md) for what this project is not.
