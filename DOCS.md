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
| `build.sh` + `profile/` | Build the Arch ISO inside Docker | Pacman package availability |
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

Rarer causes: a proxy or antivirus that rewrites text, a partial clone, or a
pinned hash that was never updated after editing a file.

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
that can work around a blocked route — do not add mirror URLs to the code just to
make one network work.

---

## 6. `Git is required` / `Python 3 is required` / `no Tk support`

**Symptom.** The installer stops during the prerequisite step.

**Cause.**

- Git missing on PATH (common in a minimal Windows image).
- `python` resolves to the Microsoft Store stub, or Python was installed without
  "Add python.exe to PATH".
- Python has no Tk: Debian/Ubuntu need `python3-tk`, Arch needs `tk`, and a
  Windows Python installed without "tcl/tk and IDLE" has no `tkinter` at all.

**Fix.**

```bash
# Debian / Ubuntu
sudo apt install python3 python3-venv python3-tk git

# Arch
sudo pacman -S python python-tk git
```

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

## 9. Release upload fails with HTTP 422 (asset too large)

**Symptom.** The build succeeds, the release step fails:

```
Validation Failed: {"resource":"ReleaseAsset","code":"custom","message":"size must be less than 2147483648"}
```

**Cause.** GitHub rejects release assets of 2 GiB or more. A full Arch ISO with
Steam, Lutris and a fat driver set easily crosses that.

**Fix.** Keep the image under 2 GiB — cut packages in `profile/packages.x86_64`
(a live preview does not need every gaming package), or publish the ISO somewhere
that allows large files and keep the release for checksums only. The workflow now
checks the size first and skips publication with an explicit message instead of
failing halfway.

---

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

## 11. `target not found` while building the ISO

**Symptom.** `pacman -S` aborts on a package name that is not in the configured
repositories.

**Cause.** Package names drift: `bluez-utils` merged into `bluez`, `nitrogen`,
`leafpad`, `wqy-zenhei-fonts`, `blue-utils` and others are gone or renamed in
Arch. Multilib-only packages (`steam`) also fail unless `[multilib]` is enabled —
`build.sh` enables it only inside the temporary profile.

**Fix.** Check the name first (`pacman -Ss <name>`), then either drop it or use
the current replacement. Keep `profile/packages.x86_64` lean; every entry is
download weight and a future breakage.

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

## 16. Download source selection: how it is meant to work

`loader.py` offers three sources: **USA · GitHub releases** (default),
**Iran · community mirror**, and **Best location · fastest ping**.

- GitHub is the only authoritative source. Its release URL is validated against
  `https://github.com/fem-dev/Prime-OS/releases/download/...` before any byte is
  written.
- The Iran entry is a *mirror hook*, not a hidden host: it does nothing until you
  set `PRIME_OS_MIRROR_IRAN=https://mirror.example.net` in the environment. The
  mirror must serve the same release path over HTTPS and the checksum is still
  verified, so a malicious mirror cannot ship a different image.
- "Best location" measures TCP connect time to `github.com` and to the mirror
  host (when configured) and picks the faster one, then reports the numbers in
  the window.

When adding a real mirror: keep it HTTPS-only, keep the checksum check, and
document the latency you measured. Do not add a source that cannot be verified.

---

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

# PowerShell syntax (on Windows or with pwsh)
pwsh -NoProfile -Command '[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path ./install.ps1), [ref]$null, [ref]$null); "parse OK"'
```

If you edited `loader.py`, remember the three installer pins and the README
commit pin; they are the most frequent cause of a "broken install" report.
