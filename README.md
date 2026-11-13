# Prime-OS

**English** · [فارسی](README.fa.md) · [العربية](README.ar.md) · [Español](README.es.md) · [Deutsch](README.de.md)

**Prime-OS** is a community-built gaming Linux project based on **Arch Linux** and the
[Hyprland](https://hyprland.org/) Wayland compositor. The current milestone is a **bootable live
ISO prototype** — not a finished installer and not a production-ready operating system.

> [!IMPORTANT]
> Nothing in this repository replaces your operating system. The setup app downloads a live image
> and saves a preferences file; it does not repartition a disk, write a USB drive, or install
> Prime-OS. Test the image in a virtual machine first, and use a spare USB drive if you test on
> real hardware.

## Quick start

You do **not** need Linux, Docker or any build step. The setup wizard downloads the published
`os.iso` from the latest GitHub release and fills the Faravahar artwork with the real download
progress — one percent downloaded is one percent of the drawing.

### Windows

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

### Linux and macOS

```bash
curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh | bash
```

Requirements: **Python 3 with Tk**, **Git**, an internet connection, and enough free space for the
image. Pillow is installed automatically into a private virtual environment.

The wizard:

1. checks the latest GitHub release for `os.iso`;
2. downloads it to the app folder with a live progress drawing;
3. verifies the size, and the published SHA-256 when the release ships a checksum file;
4. saves your hardware preference profile.

If no release has been published yet, the wizard says so plainly and only saves the profile — it
will not pretend to install anything.

| | Windows | Linux / macOS |
| --- | --- | --- |
| App files | `%LOCALAPPDATA%\Prime-OS` | `~/.local/share/prime-os` |
| Preferences | `%APPDATA%\Prime-OS\setup.json` | `~/.config/prime-os/setup.json` |

## Try the live image

Write `os.iso` to a spare USB drive with any image-writing tool, or boot it directly in a UEFI
virtual machine.

```bash
# QEMU, read-only CD-ROM, nothing on the host is modified
qemu-system-x86_64 -m 4G -smp 2 -cpu max -enable-kvm \
  -drive file=os.iso,media=cdrom,readonly=on -boot d
```

On Windows, `./run-windows.sh` boots `out/os.iso` from Git Bash (QEMU required).

### Keyboard shortcuts

| Keys | Action | Keys | Action |
| --- | --- | --- | --- |
| `Super + Enter` | Terminal (Kitty) | `Super + Q` | Close window |
| `Super + D` | Application launcher (Wofi) | `Super + F` | Fullscreen |
| `Super + B` | Firefox | `Super + V` | Toggle floating |
| `Super + G` | Steam | `Super + P` / `Super + J` | Pseudo-tile / split |
| `Super + N` | Network settings | `Super + M` | Exit Hyprland |
| `Super + 1…9` | Switch workspace | `Super + Shift + 1…9` | Move window to workspace |

## What the prototype contains

- Arch Linux live environment built with the official [`archiso`](https://wiki.archlinux.org/title/archiso) releng profile.
- Hyprland, Waybar, Wofi, Kitty, Dunst, NetworkManager and PipeWire/WirePlumber.
- Steam, Lutris, Firefox and the usual Mesa/Vulkan userspace drivers.
- A minimal first-boot graphical session as the regular, unprivileged `prime` user.
- The Faravahar setup wizard for Windows, Linux and macOS.

**Not implemented yet:** a disk installer, Secure Boot support, update/recovery flows, automatic
hardware tuning, and tested per-GPU configurations. One ISO cannot ship every proprietary driver;
NVIDIA support depends on the card model.

## Integrity and safety

- The artwork module `you.py` is fetched over HTTPS, checked against a pinned SHA-256, and only
  **parsed**, never executed by the wizard.
- The logo is size- and pixel-limited before decoding, and verified against a pinned hash.
- Release download URLs must be HTTPS and point at this repository's `releases/download` path.
- Downloads land in a `.part` file and are moved into place only after the size — and the published
  checksum, when available — match.
- Scripts verify the SHA-256 of every file they install.
- Published hashes are pinned in `install.sh`, `install.ps1` and `loader.py`; they must be updated
  together whenever those files change.

Verify a downloaded image yourself:

```bash
sha256sum os.iso          # compare with the release notes / checksum asset
```

Report a mismatch instead of booting the image.

## Building the ISO (developers only)

Building is optional and only needed if you want to change the image itself. It requires Docker and
several gigabytes of free space.

```bash
git clone https://github.com/fem-dev/Prime-OS.git
cd Prime-OS
docker run --rm --privileged \
  -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" -w /work archlinux:latest \
  bash -lc 'pacman -Syu --noconfirm archiso && bash ./build.sh'
```

`build.sh` refuses to run outside an explicitly marked Arch container, copies the installed official
releng profile into `.build/profile`, enables the `multilib` repository for Steam **in that temporary
profile only**, merges `profile/packages.x86_64`, and writes the result to `out/os.iso`.

Windows cannot build an Arch ISO directly — use WSL2 with an Arch distribution, or `build.ps1` with
Docker Desktop.

### Building in CI (GitHub Actions, no local build)

1. Open **Actions → Build and publish ISO → Run workflow**.
2. Enter a release tag (default `os-preview`) — the release is created if it does not exist.
3. The job builds in a privileged Docker container, shows **one progress bar**, then uploads
   `os.iso` and `os.iso.sha256` to that release. The full build log stays an artifact.

Pushing a `v*` tag does the same. Nothing has to be built on your own machine; a Codespace works
for interactive testing with the same Docker command, and the progress wrapper works there too.

## Repository layout

| Path | Purpose |
| --- | --- |
| `loader.py` | Setup wizard: release lookup, ISO download, artwork progress, profile |
| `install.sh` / `install.ps1` | One-command bootstrap for Linux/macOS and Windows |
| `you.py` | Faravahar vector renderer (shipped as data, parsed but not executed) |
| `faravahar.png` | Logo used by the wizard and the live session |
| `profile/packages.x86_64` | Extra packages merged into the ArchISO profile |
| `profile/airootfs/` | Files placed in the live image (Hyprland, Waybar, autologin, setup) |
| `build.sh` / `build.ps1` | Reproducible ISO build inside Docker |
| `run-windows.sh` | Boot the built ISO in QEMU from Git Bash |
| `requirements.txt` | Python dependency (`Pillow`) for the wizard |
| `.github/` | Actions workflow that builds the ISO and publishes it to releases |

The live session is started once, on `tty1`, by the `getty` autologin drop-in plus
`/etc/skel/.bash_profile`; `prime-os-live-setup` creates the unprivileged `prime` user and installs
the canonical `/etc/prime-os/hyprland.conf`.

## Project status

This is a starting point, not a finished gaming OS. Next milestones: validate the first published
image on real hardware, fix startup and package issues, design an installer, then add tested gaming
profiles plus update and recovery flows. Hardware test reports and contributions are welcome — see
[CONTRIBUTING](#contributing).

## Contributing

- Keep the ISO honest: no claims of "lag-free" gaming, no benchmark numbers without measurements.
- Test in a virtual machine before physical hardware, and never ask users to flash a drive that
  holds their data.
- If you change `loader.py`, `you.py` or `faravahar.png`, update the pinned hashes in the installers
  in the same commit — the installers fail closed on purpose.
- Report your GPU model, driver version and what worked or failed.

## License

Released under the [MIT License](LICENSE) — free to use, modify and redistribute, with no warranty.

Game performance and hardware compatibility depend on your GPU, drivers, the game and your hardware.
They cannot be guaranteed.
