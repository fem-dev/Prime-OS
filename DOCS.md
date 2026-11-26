# Prime-OS developer notes and error reference

This file is for people working **on** Prime-OS: the maintainers, contributors and
agents who build the ISO, change the installers or touch the wizard. It is not
user documentation — the user-facing text lives in `README.md`.

Every entry below is an error we have actually seen in this repository, why it
happens, and how to fix it. If you meet a new one, add it here with the same
three parts: **symptom → cause → fix**.

---

## 1. Quick mental model of the moving parts

| Piece | What it does | Where it breaks |
| --- | --- | --- |
| `install.sh` / `install-mac.sh` / `install.ps1` | Clone the repo into a temp dir, verify SHA-256 of four files, copy them to the app folder, build a Python venv, install Pillow, run the wizard | Network, line endings, Python/Tk presence |
| `loader.py` | Tk wizard: pick a download source, download `os.iso`, save a profile | GitHub API, TLS, Pillow, Tk |
| `you.py` | Faravahar artwork module; **parsed, never executed** | Hash pins |
| `faravahar.png` | The logo drawn behind the progress bar | Hash pins, Pillow |
| `build.sh` + `profile/` | Build the **setup ISO**: a minimal live environment plus the installer | Pacman package availability, archiso layout |
| `installer/prime-os-setup` + `installer/lib/*.sh` | The installer that runs on the ISO: disk, components, pacstrap, boot loader | Disk naming, mirrors, package renames |
| `components/*.list` | What the user can choose at install time; one file per component | A package renamed upstream |
| `installer/overlay/` | Files written onto the installed system (Hyprland, waybar, `issue`, key list) | Paths, permissions |
| `.github/workflows/build-iso.yml` | CI build + release upload | GitHub asset size limit (2 GiB) |

The installers **fail closed**. A hash mismatch is never a warning; it stops the
install, because the whole point is that the bytes you run are the bytes we
published.

---

## 2. `SHA-256 verification failed` (most common)

**Symptom**

```
you.py SHA-256 verification failed. The download was not installed. Hash mismatch detected.
```

or in the shell installers:

```
Prime-OS setup: SHA-256 verification failed for: /tmp/prime-os.xxx/repo/loader.py
```

**Cause.** Almost always **line endings**, not a corrupted download. On Windows
`core.autocrlf=true` rewrites `\n` to `\r\n` on checkout. The file is still
valid Python, but every byte changed, so its digest changes too:

```
LF  you.py  → 870972d63acc13b13eb2ffe44420c7e01a8366064e1ebf7ac7a6d6859ca22a36
CRLF you.py → aa4b165b77553dc71b9ea582883df62acb0ed711748e38838cd82b98771ca739
```

Rarer causes: a proxy or antivirus that rewrites text, a partial download, or a
pinned hash that was never updated after editing a file.

**The failure everyone actually hit.** The installers used to `git clone` the
moving `main` branch and then compare the result with hashes pinned in the
installer. The moment `loader.py` changed on `main`, every installer that had
already been published demanded the old bytes and refused the new ones:

```
loader.py SHA-256 verification failed.
```

That is a design bug, not a bad download. Installers now fetch the four files
from an **exact commit** (`$pinnedCommit` in `install.ps1`, `PINNED_COMMIT` in
the shell installers) over `raw.githubusercontent.com`, so the bytes and the
hashes always belong to the same revision, forever, no matter what `main` does
next. When you bump a hash you must also bump the commit — see §17.

**Fix (three layers already in the repo — keep them)**

1. `.gitattributes` pins `* text=auto eol=lf` and marks images binary. Do not
   delete it; without it every Windows clone fails immediately.
2. Every installer clones with `-c core.autocrlf=false -c core.eol=lf`.
3. Each verifier retries once after normalising CRLF → LF and then rewrites the
   file in place.

**If you changed a pinned file**, update *all* four places in the same commit:

```
install.sh      LOADER_SHA256 / ART_SHA256 / LOGO_SHA256
install-mac.sh  LOADER_SHA256 / ART_SHA256 / LOGO_SHA256
install.ps1     $expectedHashes
loader.py       ART_SHA256, LOGO_SHA256
```

Verify with `sha256sum <file>` (Linux), `shasum -a 256 <file>` (macOS) or
`Get-FileHash <file> -Algorithm SHA256` (Windows).

**Never** "fix" a mismatch by disabling the check.

---

## 3. The PowerShell window vanishes with only a red line

**Symptom.** `irm ... | iex` prints something red and the window closes before you
can read it.

**Cause.** Two different bugs stack up here:

- `exit 1` inside a script that is running through `iex` terminates the whole
  PowerShell process, and the console window goes with it.
- Any terminating error that escapes the `try/catch` did the same.

**Fix.** `install.ps1` now installs a `trap` that prints the reason and waits for
Enter, and the `catch` block no longer calls `exit`. If you add a new fatal path,
throw instead of exiting. Everything is also appended to
`%TEMP%\prime-os-install.log`, which survives the closed window.

---

## 4. `Missing ')' in method call` / `Unexpected token` in `install.ps1`

**Symptom.** PowerShell refuses to parse the file before running anything.

**Cause.** Character classes in `-match` patterns. A single quote inside a
single-quoted string closes the string, and `\\`, `\\[`, `\\]` are interpreted by
the parser. The old line was:

```powershell
if ($pass1 -match '[0-9]' -and $pass1 -match '[!@#$%^&*()_+\-=\[\]{};':\\|,.<>/?]') {
```

**Fix.** Use two simple tests instead of one exotic character class:

```powershell
if ($pass1 -match '\d' -and $pass1 -notmatch '^[a-zA-Z0-9]+$') { ... }
```

`\d` means "has a digit"; `-notmatch '^[a-zA-Z0-9]+$'` means "is not purely
alphanumeric", i.e. it contains a special character.

**Always parse before pushing:**

```powershell
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\install.ps1), [ref]$null, [ref]$null)
```

---

## 5. `irm : Unable to connect to the remote server` / `Could not connect to server`

**Symptom.** The download never starts; `git clone` reports a timeout after ~20 s.

**Cause.** The machine cannot reach `github.com` or `raw.githubusercontent.com`
(443/tcp). Corporate proxies, DNS filters, sanctions-driven blocks and some VPN
exit nodes all produce this exact message `Could not connect to server`.

**Fix.** Try in this order: turn a VPN **on**; if one was already on, turn it
**off** (some providers block GitHub themselves); change the VPN server; then
confirm `https://github.com` opens in a browser. There is nothing in the scripts
that can work around a blocked route — do not add another host to the code just to
make one network work.

---

## 6. `Python 3 is required` / `no Tk support` / `curl is required`

**Symptom.** The installer stops during the prerequisite step.

**Cause.**

- `python` resolves to the Microsoft Store stub, or Python was installed without
  "Add python.exe to PATH".
- `curl` missing on a minimal Linux image (the shell installers download the
  launcher with it; GitHub is not reachable with `wget` through every proxy).
- Python has no Tk: Debian/Ubuntu need `python3-tk`, Arch needs `tk`, and a
  Windows Python installed without "tcl/tk and IDLE" has no `tkinter` at all.

**Fix.**

```bash
# Debian / Ubuntu
sudo apt install python3 python3-venv python3-tk curl

# Arch
sudo pacman -S python python-tk curl
```

Git is **not** required any more — the installers download four files directly.
Windows: reinstall Python 3 from python.org with both PATH and Tcl/Tk options.
`install.ps1` now checks `import tkinter` inside the venv and says so explicitly.

---

## 7. `Could not install Pillow` / pip TLS errors

**Symptom.** `pip install Pillow` fails inside the venv.

**Cause.** PyPI unreachable, a TLS-intercepting proxy, or a wheel not available
for the platform. The wizard only needs **Pillow**; installing all of
`requirements.txt` pulls ~20 extra packages (`exa-py`, `openai`, `pydantic`, …)
and takes far longer, which is why the installers install Pillow alone.

**Fix.** Check `python -m pip install Pillow` manually in the venv. Behind a
proxy set `HTTPS_PROXY`. Never pin a wheel from an untrusted mirror.

---

## 8. `No Prime-OS release has been published yet` / HTTP 404

**Symptom.** The wizard opens, the progress bar stays at 0 and it offers only
"Continue to setup".

**Cause.** `repos/fem-dev/Prime-OS/releases/latest` returned 404 because no
release exists (or every release is a draft). This is a correct, intentional
state: **the wizard must not fabricate a download**.

**Fix.** Publish a release (Actions → Build and publish ISO), or accept preview
mode. HTTP **403** instead means rate limiting: wait, or use an authenticated
request.

---

## 9. The image is larger than 2 GiB (GitHub's asset limit)

**Symptom.** The build succeeds, but nothing appears on the release. Before the
fix, the log said:

```
Validation Failed: {"resource":"ReleaseAsset","code":"custom","message":"size must be less than 2147483648"}
```

**Cause.** GitHub refuses a release asset of 2 GiB or more, and the live image is
currently **~2.4 GiB**, so the old workflow skipped publication entirely — which
is why the wizard kept saying "No Prime-OS release has been published yet" even
though every build was green.

**Fix (in the workflow).** A large image is published as numbered parts plus one
small manifest:

```
os.iso.part01   1700 MiB
os.iso.part02    remainder
os-iso-parts.json   {size, sha256 of the joined file, every part's size + sha256}
```

`write_parts_manifest.py` writes the manifest, and the publish step also deletes
the assets of the other layout (`os.iso` when it now ships parts, or the parts
when it fits in one file) so the wizard can never pick a stale image.

**Fix (in the wizard).** `loader.py` prefers a single `os.iso`; when there is
none it reads `os-iso-parts.json`, downloads the parts in order into one file,
verifies **each part** against its own SHA-256, verifies the **joined** file
against the manifest, then moves it into place. A user can also join by hand:

```bash
cat os.iso.part* > os.iso
sha256sum os.iso    # must equal the manifest's sha256
```

**Why not the Actions artifact instead?** The artifact `prime-os-iso` is exactly
where the ISO sits after a build, but GitHub only lets signed-in users with read
access download artifacts, and they expire after 90 days. A wizard that cannot
log in cannot use them, so the release stays the public distribution channel.

## 10. `rm: cannot remove '.build/work/...': Permission denied` in CI

**Symptom.** The cleanup step of the workflow fails.

**Cause.** `archiso` runs as root inside the privileged container and leaves
root-owned files in `.build/`; the runner user cannot delete them.

**Fix.** Clean with the same privileges that created them:

```bash
sudo rm -rf .build
```

or chown the tree back to the runner before removing it. Do not `chmod 777`.

---

## 11. `target not found` / `Unknown package group` while building

**Symptom.** `pacman -S` aborts on a package name that is not in the configured
repositories.

**Cause.** Package names drift: `bluez-utils` merged into `bluez`, `nitrogen`,
`leafpad`, `wqy-zenhei-fonts`, `blue-utils` and others are gone or renamed in
Arch. Multilib-only packages (`steam`) also fail unless `[multilib]` is enabled —
`build.sh` enables it only inside the temporary profile.

**Fix.** Check the name first (`pacman -Ss <name>`), then either drop it or use
the current replacement.

**Where packages come from.** There is no single package list any more: every
component is its own file under `components/` (`base.list`,
`desktop.list`, `drivers-nvidia.list`, `gaming-32bit.list`, …) and `build.sh`
merges only the groups named in `PRIME_OS_GROUPS`. Consequences worth knowing:

- `base` is always built even when you forget it — the session cannot boot
  without it.
- An unknown name fails fast: `Unknown package group 'foo'. Available: apps base
  desktop …`. Add `components/foo.list` to create one.
- `multilib` is enabled in the temporary profile only when `gaming-32bit` is
  selected; without that group the build would otherwise fail on `lib32-*`.
- The selection is recorded in `out/groups.txt` and echoed into the build log, so
  a machine can tell which image it is running.
- Each group is also a weight decision: `drivers-nvidia` alone is ~1.6 GiB
  installed and `fonts-cjk` ~190 MiB compressed. That is why they are opt-in.

---

## 12. The Faravahar logo is invisible before the download

**Symptom.** The wizard shows a large empty area until bytes start arriving.

**Cause (old behaviour).** The artwork was drawn by masking the logo with the
download fraction. At 0 % the mask width was 0, so nothing was drawn at all —
correct maths, terrible first impression.

**Fix (current behaviour).** `_prepare_logo()` builds two layers once: a dim
outline (`logo_ghost`, 30 % alpha) and the gold ink mask. `_show_logo(fraction)`
always paints the outline and composites gold only up to the downloaded share.
If you refactor that code, keep the outline unconditional.

If the logo is missing entirely, the PNG failed its hash check — see §2.

---

## 13. Keyboard controls do not work in the wizard

**Symptom.** ↑ ↓ do nothing, Enter does not start the download.

**Cause.** Focus. Tk sends key events to the focused widget; a window with no
focus, or a focused `Entry`, swallows them. The bindings are registered on the
`Tk` root, so a child widget that consumes `<Up>` (a `ttk.Scale`, a text box)
blocks the handler.

**Fix.** Keep the source list plus buttons as the only interactive widgets on the
download screen, and bind on the root as the current code does. If you add an
entry widget, bind to it explicitly or use `bind_all`.

---

## 14. `you.py does not match ART_SHA256` from `--check`

**Symptom.** `python loader.py --check` exits non-zero.

**Cause.** `you.py` was edited without refreshing `ART_SHA256` (in `loader.py`)
and the pins in the three installers. Or the file was normalised to CRLF again.

**Fix.** Regenerate the digest, update `loader.py`, `install.sh`,
`install-mac.sh`, `install.ps1` in the same commit, and re-run:

```bash
python3 loader.py --check
```

---

## 15. `git pull` refuses: "Pulling is not possible because you have unmerged files"

**Symptom.** A normal `git pull` in an old clone dies with unresolved conflicts.

**Cause.** A previous merge or pull was interrupted, and history in this
repository has been rewritten more than once (commit messages were cleaned), so
old clones are not fast-forwardable.

**Fix.** Back up anything local, then align with the remote:

```bash
git fetch origin
git reset --hard origin/main
git clean -fd
```

Only resolve conflicts by hand if you really have local work to keep.

---

## 16. Where the image comes from (there are no mirrors)

`loader.py` has exactly one download source: this repository's **GitHub
releases**. There is no mirror, no fallback host and no `PRIME_OS_MIRROR_*`
environment variable. That is deliberate:

- the image and the SHA-256 that identifies it come from the same repository, so
  a third party cannot substitute a different file;
- every accepted URL must be HTTPS and start with
  `https://github.com/fem-dev/Prime-OS/releases/download/`
  (`is_allowed_github_url`), for both the image and the checksum;
- the asset name is reduced to a plain file name before it touches the disk
  (`safe_iso_name`), so release metadata can never escape the app folder.

The wizard still shows a source card, because the download destination should
never be a surprise, but it lists one entry and `Enter` starts the download.

If you ever want to add a mirror, it needs all of these, in one change: HTTPS
only, an explicit allowlist of its host, the published checksum still verified,
the latency number measured and documented, and a note in the README tables —
then update `build_sources()` and the source guards together. Do not add an
unverified mirror just to make one network reach GitHub.

## 17. Regression checklist before you push

Run the ones that apply to what you changed; all of them are cheap.

```bash
# Python
python3 -m py_compile loader.py you.py
python3 loader.py --check          # needs Pillow + the artwork next to it

# Shell
bash -n install.sh install-mac.sh

# Pinned hashes still match the files
sha256sum loader.py you.py faravahar.png requirements.txt

# The commit the installers download from still contains these exact files
git show "$(grep -oP "PINNED_COMMIT=\"\K[0-9a-f]{40}" install.sh):loader.py" | sha256sum

# PowerShell syntax (on Windows or with pwsh)
pwsh -NoProfile -Command '[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path ./install.ps1), [ref]$null, [ref]$null); "parse OK"'
```

If you edited `loader.py`, one commit must carry all of it: the new file, its
new SHA-256 in `install.sh` / `install-mac.sh` / `install.ps1` / `loader.py`, and
the **commit pin** that points at the commit containing that file (commit the
file first, then set `PINNED_COMMIT` / `$pinnedCommit` to that hash and commit
the installers). Finally re-point the Windows command in every README at the
installer commit. Skipping any of these is the most frequent cause of a
"broken install" report.

---

## 18. The setup image: what changed and what breaks

The image is no longer a finished desktop. It is an installer:

| Part | Where it lives | What it must never do |
| --- | --- | --- |
| Live environment | `profile/live-packages.list` | Grow beyond an installer (CI fails above 1.2 GiB) |
| The program | `installer/prime-os-setup` + `installer/lib/*.sh` | Run outside the ISO unless `PRIME_OS_ALLOW_NON_ISO=1` |
| Component lists | `components/*.list` + `*.desc` | Install anything nobody ticked |
| Target files | `installer/overlay/` | Carry a machine-specific value |

Adding a component means adding `components/<name>.list` and
`components/<name>.desc`. The checklist, the size estimate and the dependency
warning pick it up with no code change.

**`The ISO boots to a shell instead of the installer`**
*Symptom:* you land on `root@archiso` and no dialog appears.
*Cause:* `/root/.bash_profile` was not copied, is not executable, or `dialog` is
missing from `profile/live-packages.list`.
*Fix:* check `bash -n profile/airootfs/root/.bash_profile`, its mode (`0755`), and
run `/usr/local/bin/prime-os-setup` by hand — the symlink and its target are
created by `build.sh` under `/usr/local/lib/prime-os/`.

**`No components were found in /usr/local/share/prime-os/components`**
*Symptom:* the installer stops at the component step.
*Cause:* `build.sh` copies `components/` into that path; a build from an older
checkout, or a profile assembled by hand, does not have it.
*Fix:* rebuild with `build.sh`; while developing, export
`PRIME_OS_COMPONENTS="$PWD/components"` and run `installer/prime-os-setup`
directly on a disposable machine.

**`pacstrap: target not found: <package>` during install**
*Symptom:* the install stops while downloading.
*Cause:* a package in a component list was renamed or dropped upstream. The
installer filters unknown names with `pacman -Si` before installing, so anything
that still reaches pacstrap is a name that exists in the database but not in a
configured repository (usually multilib).
*Fix:* if the component is `gaming-32bit`, the multilib repository must be
enabled; `installer/lib/apply.sh` uncomments it in the temporary
`/tmp/prime-os-pacman.conf`. Check `/etc/pacman.conf` inside the live session.

**`The installer says it cannot reach an Arch mirror`**
*Symptom:* the retry loop ends after three attempts.
*Cause:* no DHCP lease, an unconfigured wireless card, or a network that blocks
`geo.mirror.pkgbuild.com`.
*Fix:* wire the machine, or use `nmtui` from another console (`Ctrl+Alt+F2`) and
run the installer again. A VPN is the usual answer on filtered networks; no
mirror inside the project is used, by design.

**`setup.sh: This is not a live session`**
*Symptom:* the one-line installer stops before anything else happens.
*Cause:* it was run on an installed machine (`/run/archiso` is absent). The
installer partitions a disk, so it only runs from an Arch live session.
*Fix:* boot the Arch ISO or the Prime-OS setup image and run the command there.
`PRIME_OS_ALLOW_NON_ISO=1` exists for disposable test containers only; it is not
a way to install over a system that is already running.

**`setup.sh: … stdin here is a pipe …`**
*Symptom:* the one-line installer stops before the wizard draws anything.
*Cause:* it was run as `curl … | sudo bash`. bash reads the script from that
pipe, so the wizard's `dialog` screens are left without a keyboard; `setup.sh`
refuses on purpose rather than starting a partition it cannot finish. A pipe also
needs `sudo -E` to carry `PRIME_OS_REF` into the wizard.
*Fix:* run the line without a pipe:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh)"
```

From a non-root account put `sudo` in front of the whole line, and over ssh use
`ssh -t` so a terminal is allocated.

**`setup.sh: Could not download fem-dev/Prime-OS from GitHub`**
*Symptom:* the download step fails on a live session with a working mirror.
*Cause:* GitHub is unreachable from that network, or `PRIME_OS_REF` names a
tag/commit that does not exist.
*Fix:* check the ref (`PRIME_OS_REF=main` is the default) and retry. If GitHub is
blocked, the release image path — write `os.iso` to a USB stick — needs no
GitHub access at install time.

**`The installed system boots to a black screen`**
*Symptom:* the boot loader menu appears, then nothing.
*Cause:* no graphics stack for that GPU was installed (no `drivers-*` component),
or the kernel has no module for the card.
*Fix:* boot again, add `nomodeset` to the kernel command line to reach a console,
then install the matching `drivers-*` component. This is the reason the
checklist warns when `gaming-32bit` is chosen without a driver.

**`The wizard has no mirror to fall back on`**
Not a bug. The project publishes through GitHub releases only, and the ISO is
small enough to be a single asset again. The parts manifest stays supported so an
older release can still be downloaded with a current `loader.py`.
