# Prime-OS

**Prime-OS** is an early gaming-Linux project based on Arch Linux and the Hyprland Wayland compositor. [فارسی](README.fa.md)

> Current status: an experimental setup wizard and a live-ISO build profile. **There is no published Prime-OS ISO or disk installer yet.** The wizard never repartitions, formats, flashes, or replaces your operating system. Hardware budget choices are saved as preferences only: ordinary desktop apps cannot reserve a percentage of the physical GPU or isolated RAM for an OS that is not yet installed.

## One-command preview setup

The commands below fetch the launcher and Faravahar artwork from this public GitHub repository, create an isolated Python environment, install Pillow, and start the graphical wizard. Use `bash` and `git` on Linux/macOS, or PowerShell with Git for Windows and Python 3 on Windows.

### Linux / macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

Alternative if process substitution is unavailable:

```bash
curl -fsSLO https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh && bash install.sh
```

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

For a safer option that lets you inspect the installer before running it, download `install.ps1` first and run it from disk:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 -OutFile install-prime-os.ps1
notepad .\install-prime-os.ps1
.\install-prime-os.ps1
```

## What the wizard currently does

1. Downloads the app files from the public GitHub repository.
2. Fetches the latest GitHub release metadata. **When a release with an ISO asset is published**, it downloads the ISO and reveals the Faravahar according to real bytes received. The current repository has no ISO release, so today the wizard displays that status instead of making a fake download.
3. Asks for a RAM preference and GPU budget target, and saves them to `~/.config/prime-os/setup.json` (Windows: `%USERPROFILE%\.config\prime-os\setup.json`). These values are not hardware allocations.
4. When a real, tested ISO is published, the downloaded image can be booted from a USB or in a virtual machine. The setup wizard does not install it on the host.

The loader requires only Python 3 and Pillow; its image animation uses Pillow's native image operations to avoid slowing the download UI with Python per-pixel loops.

## Developer checks

```bash
python -m pip install -r requirements.txt
python -m py_compile loader.py
python loader.py
```

To build the **experimental live ISO** separately, use Arch Linux and follow [README.fa.md](README.fa.md) and `build.sh`. The image build has not yet been validated in a full Arch VM or on physical gaming hardware.

## Project roadmap

1. Test the setup flow and loader on Windows, Linux, and macOS.
2. Build and boot the Hyprland Arch live ISO in a VM.
3. Test real GPU drivers, Steam/Proton, startup and recovery on supported hardware.
4. Only then design an opt-in installer and safe resource-management features.
