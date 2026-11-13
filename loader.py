#!/usr/bin/env python3
"""Prime-OS setup wizard and live-image downloader.

The wizard downloads the published Prime-OS live image (``os.iso``) from the
project's GitHub releases and fills the Faravahar artwork in step with the real
byte progress: one percent of the download is one percent of the drawing.

It never repartitions a disk, writes a USB drive or installs an operating
system, and it never executes the bundled ``you.py`` artwork module.
"""
from __future__ import annotations

import ast
import ctypes
import hashlib
import io
import json
import os
import platform
import subprocess
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
import tkinter as tk
from tkinter import ttk

try:
    from PIL import Image, ImageChops, ImageOps, ImageTk
except ImportError as exc:  # pragma: no cover - depends on the host environment
    raise SystemExit(
        "Prime-OS needs Pillow. Run the install command from README.md to install it."
    ) from exc

REPO = "fem-dev/Prime-OS"
RELEASES_API = f"https://api.github.com/repos/{REPO}/releases/latest"
RAW_LOGO_URL = f"https://raw.githubusercontent.com/{REPO}/main/faravahar.png"
RAW_ART_URL = f"https://raw.githubusercontent.com/{REPO}/main/you.py"

ART_SHA256 = "b1cf786a7c6781ea6093dc829b7d56d08b424d34c23caea3b2427101ae09eb86"
LOGO_SHA256 = "7a2650c3a71e26e70def9e841bb3105756b246c9fbce64de719f0b1642fd472e"

MAX_ART_BYTES = 2 * 1024 * 1024
MAX_LOGO_BYTES = 2 * 1024 * 1024
MAX_LOGO_PIXELS = 20_000_000
MAX_CHECKSUM_BYTES = 256 * 1024
CHUNK_SIZE = 256 * 1024

if os.name == "nt":
    APP_DIR = Path(
        os.environ.get(
            "PRIME_OS_HOME", Path(os.environ.get("LOCALAPPDATA", Path.home())) / "Prime-OS"
        )
    )
    CONFIG_DIR = Path(os.environ.get("APPDATA", Path.home())) / "Prime-OS"
else:
    APP_DIR = Path(
        os.environ.get("PRIME_OS_HOME", Path.home() / ".local" / "share" / "prime-os")
    )
    CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "prime-os"

BG = "#090d18"
PANEL = "#121a2a"
ACCENT = "#a78bfa"
GOLD = "#f2bb54"
TEXT = "#f4f5fb"
MUTED = "#a0abc0"

CHECKSUM_ASSET_NAMES = ("sha256sums.txt", "sha256sums", "checksums.txt", "sha256.txt")


@dataclass(frozen=True)
class IsoAsset:
    """A downloadable live image plus its optional published checksum."""

    name: str
    url: str
    size: int
    checksum_url: str | None = None


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def is_allowed_github_url(url: str) -> bool:
    """Accept only HTTPS download URLs that belong to this repository's releases."""
    parsed = urllib.parse.urlparse(url)
    return (
        parsed.scheme == "https"
        and parsed.hostname == "github.com"
        and parsed.path.startswith(f"/{REPO}/releases/download/")
    )


def total_memory_gb() -> int:
    try:
        if os.name == "nt":

            class MemoryStatus(ctypes.Structure):
                _fields_ = [
                    ("length", ctypes.c_ulong),
                    ("memoryLoad", ctypes.c_ulong),
                    ("totalPhys", ctypes.c_ulonglong),
                    ("availPhys", ctypes.c_ulonglong),
                    ("totalPageFile", ctypes.c_ulonglong),
                    ("availPageFile", ctypes.c_ulonglong),
                    ("totalVirtual", ctypes.c_ulonglong),
                    ("availVirtual", ctypes.c_ulonglong),
                    ("availExtendedVirtual", ctypes.c_ulonglong),
                ]

            status = MemoryStatus()
            status.length = ctypes.sizeof(status)
            if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
                return max(1, status.totalPhys // (1024**3))
        pages = os.sysconf("SC_PHYS_PAGES")
        page_size = os.sysconf("SC_PAGE_SIZE")
        return max(1, pages * page_size // (1024**3))
    except (AttributeError, OSError, ValueError):
        return 8


def gpu_name() -> str:
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.splitlines()[0].strip()
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired):
        pass
    return "GPU not detected automatically"


def pick_iso_asset(release: dict) -> IsoAsset | None:
    """Choose the live image from a release payload.

    ``os.iso`` is preferred; any other ``*.iso`` asset is accepted as a fallback
    so older or renamed releases still work. A published checksum asset is
    picked up automatically when the release ships one.
    """
    assets = [asset for asset in release.get("assets") or [] if isinstance(asset, dict)]
    images = [asset for asset in assets if str(asset.get("name", "")).lower().endswith(".iso")]
    if not images:
        return None
    images.sort(key=lambda asset: (str(asset.get("name", "")).lower() != "os.iso",
                                   str(asset.get("name", "")).lower()))
    image = images[0]
    image_name = str(image.get("name", ""))
    by_name = {str(asset.get("name", "")).lower(): str(asset.get("browser_download_url", ""))
               for asset in assets}
    checksum_url = by_name.get(f"{image_name.lower()}.sha256")
    if not checksum_url:
        checksum_url = next(
            (by_name[name] for name in CHECKSUM_ASSET_NAMES if by_name.get(name)), None
        )
    try:
        size = int(image.get("size") or 0)
    except (TypeError, ValueError):
        size = 0
    return IsoAsset(
        name=image_name,
        url=str(image.get("browser_download_url", "")),
        size=size,
        checksum_url=checksum_url,
    )


def expected_digest(checksum_text: str, filename: str) -> str | None:
    """Read the digest for ``filename`` out of a sha256sum-style checksum file."""
    target = filename.lower()
    for raw_line in checksum_text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.replace("*", " ").split()
        if len(parts) < 2:
            continue
        digest, name = parts[0].lower(), parts[-1].lstrip("./").lower()
        if len(digest) == 64 and name == target:
            return digest
    return None


class PrimeSetup:
    """Single-window wizard: download the image, then save a hardware profile."""

    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Prime-OS · Setup")
        self.root.configure(bg=BG)
        self.root.geometry("760x700")
        self.root.minsize(620, 620)

        available_fonts = set(self.root.tk.call("font", "families"))
        self.ui_font = next(
            (name for name in ("Segoe UI Variable", "Segoe UI", "Arial")
             if name in available_fonts),
            "TkDefaultFont",
        )
        self.root.option_add("*Font", (self.ui_font, 10))

        self.max_ram = total_memory_gb()
        self.ram_choice = tk.IntVar(value=max(1, min(4, self.max_ram - 1)))
        self.gpu_choice = tk.IntVar(value=50)
        self.progress_value = tk.DoubleVar(value=0)
        self.status = tk.StringVar(value="Connecting to the Prime-OS GitHub releases…")
        self.logo_source: Image.Image | None = None
        self.logo_photo: ImageTk.PhotoImage | None = None
        self.download_path: Path | None = None
        self.download_finished = False
        self.download_verified = False

        self._style()
        self._build_loader()
        threading.Thread(target=self._check_release_worker, daemon=True).start()

    # -- styling ---------------------------------------------------------
    def _style(self) -> None:
        style = ttk.Style(self.root)
        style.theme_use("clam")
        style.configure("TScale", background=PANEL, troughcolor="#273149")
        style.configure(
            "Prime.Horizontal.TProgressbar",
            troughcolor="#202a3d",
            background=GOLD,
            bordercolor="#202a3d",
            lightcolor=GOLD,
            darkcolor=GOLD,
            thickness=9,
        )

    # -- download screen -------------------------------------------------
    def _build_loader(self) -> None:
        wrapper = tk.Frame(self.root, bg=BG, padx=34, pady=24)
        wrapper.pack(fill="both", expand=True)
        tk.Label(
            wrapper, text="PRIME-OS", fg=TEXT, bg=BG, font=(self.ui_font, 25, "bold")
        ).pack(pady=(8, 2))
        tk.Label(
            wrapper, text="GAMING SYSTEM · EARLY PREVIEW", fg=ACCENT, bg=BG,
            font=(self.ui_font, 9, "bold"),
        ).pack(pady=(0, 12))

        self.logo_label = tk.Label(wrapper, bg=BG)
        self.logo_label.pack(pady=4)
        self.logo_hint = tk.Label(
            wrapper, text="Loading you.py artwork module…", fg=MUTED, bg=BG,
            font=(self.ui_font, 9),
        )
        self.logo_hint.pack(pady=(0, 8))

        self.progress = ttk.Progressbar(
            wrapper, style="Prime.Horizontal.TProgressbar", mode="determinate",
            maximum=100, variable=self.progress_value,
        )
        self.progress.pack(fill="x", padx=26, pady=(10, 6))
        tk.Label(
            wrapper, textvariable=self.status, fg=TEXT, bg=BG, wraplength=620,
            justify="center",
        ).pack(pady=(4, 12))

        self.continue_button = tk.Button(
            wrapper, text="Continue to setup", command=self._build_preferences,
            bg="#6845c5", fg="white", activebackground="#8060df",
            activeforeground="white", disabledforeground="#748099", relief="flat",
            padx=22, pady=10, state="disabled",
        )
        self.continue_button.pack(pady=8)
        tk.Label(
            wrapper,
            text="Preview only: this app never flashes a USB, changes partitions, "
                 "or installs over your OS.",
            fg=MUTED, bg=BG, wraplength=620, justify="center", font=(self.ui_font, 9),
        ).pack(side="bottom", pady=(12, 0))

        self._load_logo()
        threading.Thread(target=self._load_art_module, daemon=True).start()

    # -- artwork ---------------------------------------------------------
    def _load_art_module(self) -> None:
        """Fetch and validate the pinned drawing module without executing it."""
        target = APP_DIR / "you.py"
        try:
            source = Path(__file__).resolve().parent / "you.py"
            if not source.is_file():
                source = target
            if not source.is_file():
                APP_DIR.mkdir(parents=True, exist_ok=True)
                request = urllib.request.Request(
                    RAW_ART_URL, headers={"User-Agent": "Prime-OS-Setup"}
                )
                with urllib.request.urlopen(request, timeout=20) as response:
                    content = response.read(MAX_ART_BYTES + 1)
                if len(content) > MAX_ART_BYTES:
                    raise ValueError("you.py exceeds the 2 MiB safety limit")
                source = target
                source.write_bytes(content)
            content = source.read_bytes()
            if len(content) > MAX_ART_BYTES:
                raise ValueError("you.py exceeds the 2 MiB safety limit")
            if sha256_bytes(content) != ART_SHA256:
                raise ValueError("you.py SHA-256 verification failed")
            ast.parse(content, filename=str(source), mode="exec")
            self._set_art_hint("Faravahar module verified · parsed only, never executed")
        except Exception as exc:  # noqa: BLE001 - surfaced in the window
            self._set_art_hint(f"Could not load you.py: {exc}")

    def _set_art_hint(self, text: str) -> None:
        self.root.after(0, lambda: self.logo_hint.configure(text=text))

    def _load_logo(self) -> None:
        for path in (Path(__file__).resolve().parent / "faravahar.png",
                     APP_DIR / "faravahar.png"):
            try:
                raw = path.read_bytes()
                if len(raw) > MAX_LOGO_BYTES:
                    continue
                if sha256_bytes(raw) != LOGO_SHA256:
                    continue
                with Image.open(io.BytesIO(raw)) as source:
                    if source.width * source.height > MAX_LOGO_PIXELS:
                        continue
                    source.verify()
                with Image.open(io.BytesIO(raw)) as source:
                    self.logo_source = source.convert("RGBA")
                break
            except (OSError, ValueError):
                continue

        if self.logo_source is None:
            self.logo_hint.configure(text="Loading Faravahar artwork from GitHub…")
            self.status.set("Faravahar artwork is missing; downloading it from GitHub…")
            threading.Thread(target=self._download_logo_worker, daemon=True).start()
        else:
            self._show_logo(0.0)

    def _download_logo_worker(self) -> None:
        try:
            request = urllib.request.Request(
                RAW_LOGO_URL, headers={"User-Agent": "Prime-OS-Setup"}
            )
            with urllib.request.urlopen(request, timeout=20) as response:
                raw = response.read(MAX_LOGO_BYTES + 1)
            if len(raw) > MAX_LOGO_BYTES:
                raise ValueError("Faravahar image exceeds the 2 MiB safety limit")
            if sha256_bytes(raw) != LOGO_SHA256:
                raise ValueError("Faravahar image SHA-256 verification failed")
            with Image.open(io.BytesIO(raw)) as source:
                if source.width * source.height > MAX_LOGO_PIXELS:
                    raise ValueError("Faravahar image exceeds the pixel limit")
                source.verify()
            with Image.open(io.BytesIO(raw)) as source:
                image = source.convert("RGBA")
            self.root.after(0, lambda: self._set_downloaded_logo(image))
        except Exception as exc:  # noqa: BLE001 - surfaced in the window
            self.root.after(
                0, lambda error=str(exc): self.status.set(f"Could not download the logo: {error}")
            )

    def _set_downloaded_logo(self, image: Image.Image) -> None:
        self.logo_source = image
        self._show_logo(0.0)

    def _show_logo(self, fraction: float) -> None:
        """Reveal the artwork left to right, exactly in step with the download.

        ``fraction`` is the real downloaded share (0.0–1.0), so the coloured
        width of the drawing always equals the downloaded percentage.
        """
        if self.logo_source is None:
            return
        image = self.logo_source.copy()
        image.thumbnail((540, 270), Image.Resampling.LANCZOS)
        width, height = image.size
        cutoff = max(0, min(width, int(round(width * max(0.0, min(1.0, fraction))))))
        # Pillow's native channel operations keep the animation smooth at 30 fps.
        ink_alpha = ImageChops.multiply(
            image.getchannel("A"), ImageOps.invert(ImageOps.grayscale(image))
        )
        if cutoff < width:
            ink_alpha.paste(0, (cutoff, 0, width, height))
        gold = Image.new("RGBA", image.size, (255, 184, 58, 255))
        gold.putalpha(ink_alpha)
        self.logo_photo = ImageTk.PhotoImage(gold)
        self.logo_label.configure(image=self.logo_photo)

    # -- GitHub release --------------------------------------------------
    def _check_release_worker(self) -> None:
        request = urllib.request.Request(
            RELEASES_API,
            headers={"Accept": "application/vnd.github+json", "User-Agent": "Prime-OS-Setup"},
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                release = json.load(response)
            asset = pick_iso_asset(release)
            if asset is None:
                self.root.after(0, lambda: self._release_missing(
                    "The repository has no published ISO yet. The setup wizard works in "
                    "preview mode; it will not pretend to install an OS."
                ))
                return
            self.root.after(0, lambda: self._start_download(asset))
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                message = (
                    "No Prime-OS release has been published yet. You can save a hardware "
                    "preference profile, but there is no OS image to download."
                )
            elif exc.code == 403:
                message = (
                    "GitHub refused the release check (HTTP 403, likely a rate limit). "
                    "Retry in a few minutes or download os.iso from the releases page."
                )
            else:
                message = (
                    f"GitHub release check failed (HTTP {exc.code}). You can retry by "
                    "reopening the setup."
                )
            self.root.after(0, lambda: self._release_missing(message))
        except Exception as exc:  # noqa: BLE001 - surfaced in the window
            self.root.after(0, lambda error=str(exc): self._release_missing(
                f"Could not reach GitHub: {error}. Check your internet connection and try again."
            ))

    def _release_missing(self, message: str) -> None:
        self.status.set(message)
        self.logo_hint.configure(text="No ISO available — preview setup only")
        self.progress_value.set(0)
        self.continue_button.configure(state="normal")

    def _start_download(self, asset: IsoAsset) -> None:
        self.status.set(f"Downloading {asset.name} from the Prime-OS GitHub release…")
        self.logo_hint.configure(text="The Faravahar fills with the real download progress")
        APP_DIR.mkdir(parents=True, exist_ok=True)
        self.download_path = APP_DIR / asset.name
        threading.Thread(target=self._download_worker, args=(asset,), daemon=True).start()

    def _download_worker(self, asset: IsoAsset) -> None:
        destination = self.download_path
        assert destination is not None
        temporary = destination.with_suffix(destination.suffix + ".part")
        try:
            if not is_allowed_github_url(asset.url):
                raise ValueError("GitHub release asset URL is not an allowed Prime-OS HTTPS URL")
            request = urllib.request.Request(
                asset.url,
                headers={"User-Agent": "Prime-OS-Setup", "Accept": "application/octet-stream"},
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                expected = int(response.headers.get("Content-Length") or asset.size or 0)
                downloaded = 0
                with temporary.open("wb") as output:
                    while True:
                        chunk = response.read(CHUNK_SIZE)
                        if not chunk:
                            break
                        output.write(chunk)
                        downloaded += len(chunk)
                        share = downloaded / expected if expected else 0.0
                        self.root.after(0, lambda p=share: self._download_progress(p))
            if expected and downloaded != expected:
                raise IOError(f"Incomplete download: received {downloaded} of {expected} bytes")
            self._verify_checksum(temporary, asset)
            os.replace(temporary, destination)
            self.root.after(0, lambda: self._download_complete(asset))
        except Exception as exc:  # noqa: BLE001 - surfaced in the window
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass
            self.root.after(0, lambda error=str(exc): self._release_missing(
                f"ISO download failed: {error}"
            ))

    def _verify_checksum(self, path: Path, asset: IsoAsset) -> None:
        """Verify the published SHA-256 when the release ships one; warn otherwise."""
        if not asset.checksum_url:
            self.download_verified = False
            return
        if not is_allowed_github_url(asset.checksum_url):
            raise ValueError("Checksum URL is not an allowed Prime-OS HTTPS URL")
        request = urllib.request.Request(
            asset.checksum_url, headers={"User-Agent": "Prime-OS-Setup"}
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            text = response.read(MAX_CHECKSUM_BYTES).decode("utf-8", "replace")
        digest = expected_digest(text, asset.name)
        if digest is None:
            self.download_verified = False
            return
        actual = hashlib.sha256()
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(CHUNK_SIZE), b""):
                actual.update(block)
        if actual.hexdigest() != digest:
            raise ValueError("SHA-256 checksum mismatch: the image is corrupted")
        self.download_verified = True

    def _download_progress(self, share: float) -> None:
        value = max(0.0, min(1.0, share))
        self.progress_value.set(value * 100)
        self._show_logo(value)
        self.status.set(f"Downloading Prime-OS image… {int(value * 100)}%")

    def _download_complete(self, asset: IsoAsset) -> None:
        self.download_finished = True
        self.progress_value.set(100)
        self._show_logo(1.0)
        if self.download_verified:
            self.logo_hint.configure(text="Download complete · SHA-256 checksum verified")
        elif asset.size or asset.checksum_url:
            self.logo_hint.configure(text="Download complete · verified against the published size")
        else:
            self.logo_hint.configure(text="Download complete · no checksum was published")
        self.status.set(
            f"Downloaded {asset.name}. Continue to choose your hardware preferences."
        )
        self.continue_button.configure(state="normal")

    # -- preferences -----------------------------------------------------
    def _build_preferences(self) -> None:
        for child in self.root.winfo_children():
            child.destroy()
        wrapper = tk.Frame(self.root, bg=BG, padx=40, pady=28)
        wrapper.pack(fill="both", expand=True)
        tk.Label(
            wrapper, text="Choose your gaming profile", fg=TEXT, bg=BG,
            font=(self.ui_font, 23, "bold"),
        ).pack(anchor="w", pady=(4, 8))
        tk.Label(
            wrapper, text=f"Detected system memory: {self.max_ram} GB", fg=MUTED, bg=BG
        ).pack(anchor="w", pady=(0, 12))

        ram_box = tk.Frame(wrapper, bg=PANEL, padx=18, pady=15)
        ram_box.pack(fill="x", pady=9)
        tk.Label(
            ram_box, text="Memory budget", fg=TEXT, bg=PANEL, font=(self.ui_font, 12, "bold")
        ).pack(anchor="w")
        ram_value = tk.Label(ram_box, text="", fg=ACCENT, bg=PANEL)
        ram_value.pack(anchor="e")
        ram_limit = max(1, self.max_ram - 1)
        ram = ttk.Scale(
            ram_box, from_=1, to=ram_limit,
            command=lambda value: (
                self.ram_choice.set(round(float(value))),
                ram_value.configure(text=f"{self.ram_choice.get()} GB"),
            ),
        )
        ram.set(self.ram_choice.get())
        ram.pack(fill="x", pady=6)
        ram_value.configure(text=f"{self.ram_choice.get()} GB")

        gpu_box = tk.Frame(wrapper, bg=PANEL, padx=18, pady=15)
        gpu_box.pack(fill="x", pady=9)
        tk.Label(
            gpu_box, text="Graphics budget target", fg=TEXT, bg=PANEL,
            font=(self.ui_font, 12, "bold"),
        ).pack(anchor="w")
        self.gpu_label = tk.Label(gpu_box, text="", fg=ACCENT, bg=PANEL)
        self.gpu_label.pack(anchor="e")
        gpu = ttk.Scale(gpu_box, from_=5, to=100, command=self._set_gpu_label)
        gpu.set(self.gpu_choice.get())
        gpu.pack(fill="x", pady=6)
        self._set_gpu_label(str(self.gpu_choice.get()))
        tk.Label(
            gpu_box,
            text=gpu_name() + " · This is a preference only; ordinary PCs cannot reserve "
                              "a GPU by percentage.",
            fg=MUTED, bg=PANEL, wraplength=610, justify="left",
        ).pack(anchor="w", pady=(5, 0))

        tk.Label(
            wrapper,
            text="These choices are saved as a profile. RAM/GPU are not actually allocated "
                 "until Prime-OS has a tested installer or VM backend.",
            fg=MUTED, bg=BG, wraplength=640, justify="left",
        ).pack(anchor="w", pady=12)
        tk.Button(
            wrapper, text="Save profile", command=self._save_profile, bg="#6845c5",
            fg="white", activebackground="#8060df", activeforeground="white",
            relief="flat", padx=20, pady=10,
        ).pack(anchor="w", pady=8)

    def _set_gpu_label(self, value: str) -> None:
        self.gpu_choice.set(round(float(value)))
        self.gpu_label.configure(text=f"{self.gpu_choice.get()}% target")

    def _save_profile(self) -> None:
        profile = {
            "ram_gb": max(1, min(max(1, self.max_ram - 1), self.ram_choice.get())),
            "gpu_budget_percent": self.gpu_choice.get(),
            "gpu_detected": gpu_name(),
            "iso_downloaded": str(self.download_path) if self.download_finished else None,
            "iso_checksum_verified": self.download_verified,
            "mode": "preview-only; hardware allocation and OS installation are not implemented",
        }
        CONFIG_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
        config_path = CONFIG_DIR / "setup.json"
        config_path.write_text(json.dumps(profile, indent=2), encoding="utf-8")
        if os.name != "nt":
            os.chmod(CONFIG_DIR, 0o700)
            os.chmod(config_path, 0o600)

        for child in self.root.winfo_children():
            child.destroy()
        wrapper = tk.Frame(self.root, bg=BG, padx=40, pady=40)
        wrapper.pack(fill="both", expand=True)
        tk.Label(
            wrapper, text="Profile saved", fg=TEXT, bg=BG, font=(self.ui_font, 24, "bold")
        ).pack(anchor="w", pady=(20, 10))
        if self.download_finished:
            detail = (
                f"Your Prime-OS live image is ready at:\n{self.download_path}\n\n"
                "Write it to a spare USB drive or boot it in a virtual machine to start the "
                "live desktop. This wizard does not install it onto your computer."
            )
        else:
            detail = (
                "No operating-system image has been published on GitHub yet, so the desktop "
                "cannot be started. Your preference profile is saved; publish a tested "
                "Prime-OS release to continue."
            )
        tk.Label(
            wrapper, text=detail, fg=MUTED, bg=BG, wraplength=620, justify="left"
        ).pack(anchor="w", pady=12)
        tk.Label(
            wrapper, text=f"Saved to: {config_path}", fg=ACCENT, bg=BG, wraplength=620,
            justify="left",
        ).pack(anchor="w", pady=5)
        tk.Button(
            wrapper, text="Close", command=self.root.destroy, bg="#6845c5", fg="white",
            activebackground="#8060df", activeforeground="white", relief="flat",
            padx=20, pady=9,
        ).pack(anchor="w", pady=16)


def self_check() -> None:
    """Offline sanity check used by packagers and the installers."""
    logo = Path(__file__).resolve().parent / "faravahar.png"
    art = Path(__file__).resolve().parent / "you.py"
    if not logo.is_file():
        raise SystemExit(f"Faravahar image is missing: {logo}")
    if sha256_bytes(logo.read_bytes()) != LOGO_SHA256:
        raise SystemExit("Faravahar image does not match LOGO_SHA256")
    if art.is_file():
        if sha256_bytes(art.read_bytes()) != ART_SHA256:
            raise SystemExit("you.py does not match ART_SHA256")
        ast.parse(art.read_text(encoding="utf-8"), filename=str(art), mode="exec")
    with Image.open(logo) as image:
        image.verify()
    print(
        f"Prime-OS setup checks passed · Python {platform.python_version()} "
        f"· Pillow {Image.__version__}"
    )
    print(f"Faravahar image is valid: {logo}")
    print(f"GitHub release API: {RELEASES_API}")


def main() -> None:
    if "--check" in sys.argv:
        self_check()
        return
    root = tk.Tk()
    PrimeSetup(root)
    root.mainloop()


if __name__ == "__main__":
    main()
