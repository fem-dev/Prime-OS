# -*- coding: utf-8 -*-
"""
Faravahar graphic only (no animation, no progress bar).
Traces your Faravahar image into vector shapes and draws it in gold / blue.

    python faravahar_graphic.py Untitled.png              # show it
    python faravahar_graphic.py Untitled.png --save       # also writes faravahar.png
    python faravahar_graphic.py Untitled.png --no-disc    # no blue ring
"""
import sys
import subprocess
import importlib.util

MIRROR = "https://liara.ir/mirrors/pypi/"        # <- exact index URL of the mirror
NEEDED = {"numpy": "numpy", "matplotlib": "matplotlib", "PIL": "pillow",
          "contourpy": "contourpy"}


def install_deps():
    missing = [p for m, p in NEEDED.items() if importlib.util.find_spec(m) is None]
    if not missing:
        return
    base = MIRROR.rstrip("/")
    for index in (base + "/simple/", base + "/", None):
        cmd = [sys.executable, "-m", "pip", "install", "--upgrade", *missing]
        if index:
            cmd += ["--index-url", index]
        print("[..]", " ".join(cmd))
        if subprocess.call(cmd) == 0:
            return
    sys.exit("Could not install: " + ", ".join(missing))


if __name__ == "__main__":        # importing this module must never install anything
    install_deps()

import time                                                      # noqa: E402
import io                                                        # noqa: E402
import os                                                        # noqa: E402
import urllib.request                                            # noqa: E402
import logging                                                   # noqa: E402
logging.getLogger("matplotlib.font_manager").setLevel(logging.ERROR)
import numpy as np                                               # noqa: E402
import matplotlib                                                # noqa: E402
if "--preview" in sys.argv:
    matplotlib.use("Agg")
import matplotlib.pyplot as plt                                  # noqa: E402
from matplotlib.animation import FuncAnimation, PillowWriter     # noqa: E402
from matplotlib.patches import Rectangle                         # noqa: E402
from matplotlib.path import Path                                 # noqa: E402
from PIL import Image, ImageFilter                               # noqa: E402
from contourpy import contour_generator, FillType                # noqa: E402

BG = "#07070d"
NG = 12                       # number of drawing layers
MAX_SIDE = 900                # working resolution of the image
MAX_IMAGE_BYTES = 16 * 1024 * 1024   # refuse larger inputs before decoding them
MAX_IMAGE_PIXELS = 40_000_000
MIN_AREA = 25                 # ignore specks smaller than this (pixels^2)
BANDS = int(sys.argv[sys.argv.index("--bands") + 1]) if "--bands" in sys.argv else 1
RING_PTS = 160                # max vertices per traced ring


# ----------------------------------------------------------------------
# image -> shapes
# ----------------------------------------------------------------------
def load_image(src):
    if src.startswith("http"):
        req = urllib.request.Request(src, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as response:
            data = response.read(MAX_IMAGE_BYTES + 1)
        if len(data) > MAX_IMAGE_BYTES:
            raise ValueError("Image exceeds the 16 MiB safety limit")
        source = io.BytesIO(data)
    else:
        if os.path.getsize(src) > MAX_IMAGE_BYTES:
            raise ValueError("Image exceeds the 16 MiB safety limit")
        source = src
    with Image.open(source) as image:
        if image.width * image.height > MAX_IMAGE_PIXELS:
            raise ValueError("Image exceeds the pixel limit")
        return image.convert("RGBA")


def make_mask(img, invert=False):
    s = MAX_SIDE / max(img.size)
    img = img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)
    arr = np.asarray(img).astype(float)
    rgb, alpha = arr[..., :3], arr[..., 3]
    lineart = False
    if alpha.min() < 200:                                   # transparent PNG
        m = alpha / 255.0
    else:                                                   # opaque: separate from background
        border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
        bg = np.median(border, axis=0)
        dist = np.linalg.norm(rgb - bg, axis=2)
        lineart = bg.mean() > 180                            # dark ink on light paper
        m = (dist > max(30, 0.35 * dist.max())).astype(float)
    if invert:
        m = 1 - m
    m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(1.1))) / 255.0
    ys, xs = np.where(m > 0.5)
    if ys.size == 0 or xs.size == 0:                # blank image, nothing to trace
        raise ValueError("The image has no visible area to trace")
    pad = 6
    y0, y1 = max(0, ys.min() - pad), min(m.shape[0], ys.max() + pad)
    x0, x1 = max(0, xs.min() - pad), min(m.shape[1], xs.max() + pad)
    return rgb[y0:y1, x0:x1], m[y0:y1, x0:x1], lineart


def resample_ring(P, n=None):
    d = np.r_[0, np.cumsum(np.hypot(*np.diff(P, axis=0).T))]
    n = int(np.clip(d[-1] / 2.2, 20, 700))               # point count follows the length
    if len(P) <= n:
        return P
    t = np.linspace(0, d[-1], n)
    return np.c_[np.interp(t, d, P[:, 0]), np.interp(t, d, P[:, 1])]


def poly_area(P):
    return 0.5 * abs(np.dot(P[:, 0], np.roll(P[:, 1], 1)) - np.dot(P[:, 1], np.roll(P[:, 0], 1)))


def trace(rgb, mask, lineart=False):
    h, w = mask.shape
    pts_list, off_list, kinds = [], [], []
    if BANDS <= 1:
        gen = contour_generator(z=mask, fill_type=FillType.OuterOffset)
        pts_list, off_list = gen.filled(0.5, 2.0)
        kinds = ["ink"] * len(pts_list)
        if lineart:                         # also the enclosed white areas (feather panels etc.)
            gen2 = contour_generator(z=1 - mask, fill_type=FillType.OuterOffset)
            a, b = gen2.filled(0.5, 2.0)
            for pts, off in zip(a, b):
                o = pts[off[0]:off[1]]
                if (o[:, 0].max() - o[:, 0].min()) >= w - 4 and (o[:, 1].max() - o[:, 1].min()) >= h - 4:
                    continue                # the outer paper background
                pts_list.append(pts)
                off_list.append(off)
                kinds.append("fill")
    else:                                   # split the logo into tonal bands (keeps inner detail)
        lum = np.asarray(Image.fromarray(rgb.mean(axis=2).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(1.0))).astype(float)
        inside_vals = lum[mask > 0.5]
        edges = np.percentile(inside_vals, np.linspace(0, 100, BANDS + 1))
        edges[0], edges[-1] = -1, 256
        z = np.where(mask > 0.5, lum, -50.0)
        gen = contour_generator(z=z, fill_type=FillType.OuterOffset)
        for lo, hi in zip(edges[:-1], edges[1:]):
            a, b = gen.filled(lo, hi)
            pts_list += list(a)
            off_list += list(b)
            kinds += ["ink"] * len(a)

    sat = (rgb.max(axis=2) - rgb.min(axis=2))[mask > 0.5]
    coloured = sat.size > 0 and np.median(sat) > 25          # does the image have real colour?

    scale = min(11.6 / w, 6.4 / h)
    shapes = []
    for pts, off, kind in zip(pts_list, off_list, kinds):
        rings = [pts[off[j]:off[j + 1]] for j in range(len(off) - 1)]
        if poly_area(rings[0]) < MIN_AREA:
            continue
        outer = rings[0]
        # colour: sample the image inside the outer ring
        x0, x1 = int(outer[:, 0].min()), int(outer[:, 0].max()) + 1
        y0, y1 = int(outer[:, 1].min()), int(outer[:, 1].max()) + 1
        gx, gy = np.meshgrid(np.linspace(x0, x1, 14), np.linspace(y0, y1, 14))
        g = np.c_[gx.ravel(), gy.ravel()]
        inside = Path(outer).contains_points(g)
        if inside.any():
            sel = g[inside].astype(int)
            sel[:, 0] = np.clip(sel[:, 0], 0, w - 1)
            sel[:, 1] = np.clip(sel[:, 1], 0, h - 1)
            col = rgb[sel[:, 1], sel[:, 0]].mean(axis=0) / 255.0
        else:
            col = np.array([0.95, 0.76, 0.3])
        cy = outer[:, 1].mean()
        if lineart:
            col = np.array([0.17, 0.09, 0.04])                # ink strokes: deep bronze
        if lineart and kind == "fill":                        # paper areas become gold
            u = cy / h
            col = np.array([0.98, 0.80, 0.32]) * (1 - u) + np.array([0.80, 0.45, 0.12]) * u
        elif not coloured and not lineart:                    # gold palette by height
            u = cy / h                                        # 0 = top, 1 = bottom
            col = np.array([0.96, 0.78, 0.30]) * (1 - u) + np.array([0.72, 0.38, 0.11]) * u
        fixed = []
        for r in rings:
            r = resample_ring(r, RING_PTS)
            r = np.c_[(r[:, 0] - w / 2) * scale, -(r[:, 1] - h / 2) * scale]   # centre + flip y
            fixed.append(r)
        shapes.append(dict(rings=fixed, rgb=np.clip(col, 0, 1), kind=kind, cy=-(cy - h / 2) * scale,
                           area=poly_area(outer)))
    # drawing order: bottom of the logo first, then upwards
    shapes.sort(key=lambda s: s["cy"])
    n = len(shapes)
    for i, s in enumerate(shapes):
        s["g"] = min(NG - 1, i * NG // max(n, 1))
    return shapes, w * scale, h * scale


def palette(yn, xn, jit):
    """yn: 0 bottom..1 top. Warm gold gradient, brighter near the centre."""
    lo, mid, hi = np.array([0.74, 0.40, 0.09]), np.array([0.96, 0.70, 0.18]), np.array([1.0, 0.90, 0.52])
    c = lo * (1 - 2 * yn) + mid * 2 * yn if yn < 0.5 else mid * (2 - 2 * yn) + hi * (2 * yn - 1)
    return np.clip(c * (1 + 0.12 * (1 - abs(xn))) * (1 + jit), 0, 1)


def draw_faravahar(ax, shapes, W, H, lineart=True, blue_disc=True):
    """Draw the traced shapes on a matplotlib axes (data units: width ~11.6, height ~6.4)."""
    from matplotlib.patches import PathPatch
    rng = np.random.default_rng(3)
    for sh in shapes:
        pts = np.vstack(sh["rings"])
        codes = np.concatenate([[Path.MOVETO] + [Path.LINETO] * (len(r) - 2) + [Path.CLOSEPOLY]
                                for r in sh["rings"]])
        cx, cy = sh["rings"][0].mean(axis=0)
        ink = sh["kind"] == "ink"
        col = sh["rgb"]
        if lineart and not ink:
            col = palette((cy + H / 2) / H, cx / (W / 2), rng.uniform(-0.09, 0.09))
            if blue_disc and np.hypot(cx, cy + 0.045 * H) < 0.078 * W:
                col = np.clip(np.array([0.16, 0.38, 0.85]) * rng.uniform(0.85, 1.1), 0, 1)
        ax.add_patch(PathPatch(Path(pts, codes), fc=col, ec=(0.98, 0.80, 0.35), lw=1.1,
                               zorder=3 if ink else 2))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    src = args[0] if args else "faravahar.png"
    rgb, mask, lineart = make_mask(load_image(src), invert="--invert" in sys.argv)
    shapes, W, H = trace(rgb, mask, lineart)

    fig = plt.figure(figsize=(9, 5.4), facecolor=BG)
    ax = fig.add_axes([0, 0, 1, 1], facecolor=BG)
    ax.set_xlim(-7.2, 7.2)
    ax.set_ylim(-4.3, 4.3)
    ax.set_aspect("equal")
    ax.axis("off")
    draw_faravahar(ax, shapes, W, H, lineart, blue_disc="--no-disc" not in sys.argv)
    if "--save" in sys.argv:
        fig.savefig("faravahar.png", dpi=200, facecolor=BG)
        print("saved faravahar.png")
    plt.show()


if __name__ == "__main__":
    main()