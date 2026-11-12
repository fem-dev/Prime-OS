# -*- coding: utf-8 -*-
"""
Faravahar DOWNLOAD BAR.
The real Faravahar artwork (traced from your image) is the progress bar:
every percent draws ONE more line (one at a time) and colours it.
At 100% it shines and the word COMPLETE appears. Then it loops.

    python loader.py faravahar.png
    python loader.py faravahar.png --download https://example.com/system.iso --output system.iso
    python loader.py faravahar.png --preview
    add --invert if the logo is light-on-dark and tracing looks wrong

With --download, progress is based on bytes actually received (the server must
send Content-Length); the ISO is written to a temporary file and renamed only
when the complete download has been verified.
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


install_deps()

import time                                                      # noqa: E402
import io                                                        # noqa: E402
import os                                                        # noqa: E402
import threading                                                 # noqa: E402
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
MIN_AREA = 25                 # ignore specks smaller than this (pixels^2)
BANDS = int(sys.argv[sys.argv.index("--bands") + 1]) if "--bands" in sys.argv else 1
RING_PTS = 160                # max vertices per traced ring


# ----------------------------------------------------------------------
# image -> shapes
# ----------------------------------------------------------------------
def load_image(src):
    if src.startswith("http"):
        req = urllib.request.Request(src, headers={"User-Agent": "Mozilla/5.0"})
        data = urllib.request.urlopen(req, timeout=30).read()
        return Image.open(io.BytesIO(data)).convert("RGBA")
    return Image.open(src).convert("RGBA")


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


# ----------------------------------------------------------------------
# timeline: download (progress) -> COMPLETE text + shine -> hold -> fade -> loop
# ----------------------------------------------------------------------
DL, T_TXT, T_SHINE, T_HOLD, T_FADE = 300, 40, 46, 50, 30
A = DL
B = A + T_TXT
C = B + T_SHINE
D = C + T_HOLD
TOTAL = D + T_FADE
LAG = 0.03                                   # colour follows the line by 3 %
GOLD_LINE = np.array([0.98, 0.80, 0.35])
WHITE = np.ones(3)
FONTS = ["Cinzel", "Trajan Pro", "Optima", "Palatino Linotype", "Georgia", "DejaVu Serif"]


def ease(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def progress(f):
    return float(np.clip(f / DL, 0, 1))


def start_download(url, destination):
    """Download in the background and publish byte-accurate progress to the UI."""
    state = {"progress": 0.0, "done": False, "error": None, "completed_at": None}
    lock = threading.Lock()
    destination = os.path.abspath(destination)
    temporary = destination + ".part"

    def worker():
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=30) as response:
                total = int(response.headers.get("Content-Length") or 0)
                if total <= 0:
                    raise ValueError("The server did not provide a valid Content-Length")
                downloaded = 0
                with open(temporary, "wb") as output:
                    while True:
                        chunk = response.read(256 * 1024)
                        if not chunk:
                            break
                        output.write(chunk)
                        downloaded += len(chunk)
                        with lock:
                            state["progress"] = min(downloaded / total, 1.0)
                if downloaded != total:
                    raise IOError(f"Incomplete download: received {downloaded} of {total} bytes")
            os.replace(temporary, destination)
            with lock:
                state["progress"] = 1.0
                state["done"] = True
                state["completed_at"] = time.monotonic()
        except Exception as exc:
            try:
                if os.path.exists(temporary):
                    os.remove(temporary)
            except OSError:
                pass
            with lock:
                state["error"] = str(exc)

    threading.Thread(target=worker, name="os-download", daemon=True).start()
    return state, lock


def palette(yn, xn, jit):
    """yn: 0 bottom..1 top.  Warm gold gradient, brighter near the centre."""
    lo, mid, hi = np.array([0.74, 0.40, 0.09]), np.array([0.96, 0.70, 0.18]), np.array([1.0, 0.90, 0.52])
    c = lo * (1 - 2 * yn) + mid * 2 * yn if yn < 0.5 else mid * (2 - 2 * yn) + hi * (2 * yn - 1)
    c = c * (1 + 0.12 * (1 - abs(xn))) * (1 + jit)
    return np.clip(c, 0, 1)


def main():
    from matplotlib.collections import PolyCollection, LineCollection
    import matplotlib.patheffects as pe
    def option_value(name, default=None):
        try:
            return sys.argv[sys.argv.index(name) + 1]
        except (ValueError, IndexError):
            return default

    consumed = {option_value("--download"), option_value("--output"), option_value("--bands")}
    args = [a for a in sys.argv[1:] if not a.startswith("--") and not a.isdigit() and a not in consumed]
    src = args[0] if args else "faravahar.png"
    download_url = option_value("--download")
    download_state, download_lock = start_download(download_url, option_value("--output", "system-image.iso")) if download_url else (None, None)
    rgb, mask, lineart = make_mask(load_image(src), invert="--invert" in sys.argv)
    shapes, W, H = trace(rgb, mask, lineart)
    S = len(shapes)

    fig = plt.figure(figsize=(8.8, 6.2), facecolor=BG)
    ax = fig.add_axes([0, 0, 1, 1], facecolor=BG)
    yy, xx = np.mgrid[-1:1:160j, -1:1:230j]
    rr = np.clip(np.hypot(xx * 0.9, yy), 0, 1)[..., None]
    bg = np.array([0.10, 0.09, 0.16]) * (1 - rr) + np.array([0.02, 0.02, 0.04]) * rr
    ax.imshow(bg, extent=[-7.2, 7.2, -5.0, 5.0], zorder=-5, aspect="auto")
    ax.set_xlim(-7.2, 7.2)
    ax.set_ylim(-5.0, 5.0)
    ax.set_aspect("equal")
    ax.axis("off")

    # ---- flatten geometry, build "units" (one ring = one line that gets drawn) ----
    V0 = np.vstack([r for sh in shapes for r in sh["rings"]])
    sh_range, ring_a, ring_n, ring_of = [], [], [], {}
    pos = 0
    for si, sh in enumerate(shapes):
        a0 = pos
        for j, r in enumerate(sh["rings"]):
            ring_of[(si, j)] = len(ring_a)
            ring_a.append(pos)
            ring_n.append(len(r))
            pos += len(r)
        sh_range.append((a0, pos))
        sh["codes"] = np.concatenate([[Path.MOVETO] + [Path.LINETO] * (len(r) - 2) + [Path.CLOSEPOLY]
                                      for r in sh["rings"]])
    ring_a, ring_n = np.array(ring_a), np.array(ring_n)

    units = []                                      # (shape, ring_global, cx, cy, perimeter)
    for si, sh in enumerate(shapes):
        for j, r in enumerate(sh["rings"]):
            if lineart and j > 0:                   # holes are already the outlines of other shapes
                continue
            per = float(np.sum(np.hypot(*np.diff(r, axis=0).T)))
            units.append((si, ring_of[(si, j)], r[:, 0].mean(), r[:, 1].mean(), per))
    band = H / 16
    is_ink_shape = [sh["kind"] == "ink" for sh in shapes]
    units.sort(key=lambda u: (is_ink_shape[u[0]], int((u[3] + H / 2) // band), u[2]))   # panels sweep bottom->top, outline closes last
    U = len(units)
    u_shape = np.array([u[0] for u in units])
    u_ring = np.array([u[1] for u in units])
    dur = np.array([u[4] for u in units]) ** 0.7                         # long lines take longer
    ends = np.cumsum(dur) / dur.sum()
    starts = np.r_[0, ends[:-1]]
    shape_end = np.zeros(S)
    for ui, si in enumerate(u_shape):
        shape_end[si] = max(shape_end[si], ends[ui])
    print(f"traced {S} shapes -> {U} lines, one at a time")

    is_ink = np.array([sh["kind"] == "ink" for sh in shapes])
    rng = np.random.default_rng(3)
    cx_s = np.array([V0[a:b, 0].mean() for a, b in sh_range])
    cy_s = np.array([V0[a:b, 1].mean() for a, b in sh_range])
    base = np.array([palette((cy_s[i] + H / 2) / H, cx_s[i] / (W / 2), rng.uniform(-0.09, 0.09))
                     if (lineart and not is_ink[i]) else shapes[i]["rgb"] for i in range(S)])
    if lineart and "--no-disc" not in sys.argv:          # central ring (lapis blue), tuned for the classic drawing
        d = np.hypot(cx_s, cy_s + 0.045 * H)
        inside = (d < 0.078 * W) & ~is_ink
        shade = rng.uniform(0.85, 1.1, S)[:, None]
        base[inside] = np.clip(np.array([0.16, 0.38, 0.85])[None] * shade[inside], 0, 1)

    def make_poly(idx, z):
        col = PolyCollection([V0[sh_range[i][0]:sh_range[i][1]] for i in idx], closed=False,
                             linewidths=0, zorder=z)
        col.set_verts_and_codes([V0[sh_range[i][0]:sh_range[i][1]] for i in idx],
                                [shapes[i]["codes"] for i in idx])
        ax.add_collection(col)
        return col

    fill_idx, ink_idx = np.where(~is_ink)[0], np.where(is_ink)[0]
    layers = [(fill_idx, make_poly(fill_idx, 2)), (ink_idx, make_poly(ink_idx, 3))]
    lines = LineCollection([], linewidths=1.3, capstyle="round", zorder=5)
    ax.add_collection(lines)
    halo = ax.scatter([], [], s=260, c="#ffcf6b", alpha=0.25, zorder=7, linewidths=0)
    head = ax.scatter([], [], s=45, c="white", zorder=8, linewidths=0)

    # ---- download-bar UI ----
    TX0, TX1, BY = -4.4, 4.4, -4.0
    ax.add_patch(Rectangle((TX0, BY), TX1 - TX0, 0.14, fc="#16140f", ec="#6b5521", lw=1, zorder=4))
    barfill = Rectangle((TX0, BY), 0.0, 0.14, fc="#f2b632", ec="none", zorder=5)
    ax.add_patch(barfill)
    glow = [pe.withStroke(linewidth=4, foreground="#5a3a05")]
    label = ax.text(TX0, BY + 0.38, "D O W N L O A D I N G", color="#cfa84a", fontsize=11,
                    family=FONTS, va="center", ha="left", zorder=6)
    pct = ax.text(TX1, BY + 0.38, "0%", color="#ffe29a", fontsize=15, family=FONTS,
                  va="center", ha="right", zorder=6, path_effects=glow)
    word = "COMPLETE"
    xs = (np.arange(8) - 3.5) * 0.74
    letters = [ax.text(x, -4.62, ch, color="#ffe29a", fontsize=30, family=FONTS, weight="bold",
                       ha="center", va="center", alpha=0, zorder=6, path_effects=glow)
               for x, ch in zip(xs, word)]
    ax.set_xlim(-7.2, 7.2)
    ax.set_ylim(-5.0, 5.0)

    dyn = [*[c for _, c in layers], lines, halo, head, barfill, label, pct, *letters]
    for art in dyn:
        art.set_animated(True)               # redrawn every frame; background/track are cached (blit)

    def update(f):
        if download_state:
            with download_lock:
                state = download_state.copy()
            p = state["progress"]
            if state["done"]:
                f = DL + min((time.monotonic() - state["completed_at"]) * 30, TOTAL - DL)
            else:
                f = DL * p
        p = progress(f) if not download_state else p
        x = p
        a_g = 1.0 if download_state else 1.0 - max(0.0, (f - D) / T_FADE)
        # lines: one unit at a time
        line = np.clip((x - starts) / (ends - starts), 0, 1)
        fillv = ease((x - shape_end) / LAG)
        hot = np.clip(1 - (x - ends) / LAG, 0, 1) * (line > 0)          # bright "just drawn" glow
        face = 0.97 * fillv * a_g
        rgbf = base.copy()
        edge = GOLD_LINE[None] * (1 - hot[:, None]) + WHITE[None] * hot[:, None]
        if B <= f < C:                                                    # shine sweep at 100 %
            sx = -W / 2 - 2 + (f - B) / T_SHINE * (W + 4)
            lift = np.exp(-((cx_s - sx) / 1.3) ** 2) * 0.65
            rgbf = rgbf * (1 - lift[:, None]) + lift[:, None]
        for idx, col in layers:
            col.set_facecolor(np.c_[rgbf[idx], face[idx]])
        m = np.rint(line * ring_n[u_ring]).astype(int)
        vis = np.where(m >= 2)[0]
        lines.set_segments([V0[ring_a[u_ring[i]]:ring_a[u_ring[i]] + m[i]] for i in vis])
        lines.set_color(np.c_[edge[vis], np.full(len(vis), a_g)])
        act = np.where((line > 0) & (line < 1))[0]
        if len(act) and f < A:
            pts = np.array([V0[ring_a[u_ring[i]] + m[i] - 1] for i in act])
            head.set_offsets(pts)
            halo.set_offsets(pts)
        else:
            head.set_offsets(np.empty((0, 2)))
            halo.set_offsets(np.empty((0, 2)))
        # bar + text
        barfill.set_width((TX1 - TX0) * p)
        barfill.set_alpha(a_g)
        pct.set_text(f"{int(p * 100)}%")
        if download_state and state["error"]:
            label.set_text("DOWNLOAD FAILED")
        elif download_state and state["done"]:
            label.set_text("DOWNLOAD COMPLETE")
        ui = 1.0 if download_state else (1.0 - min(1.0, max(0.0, (f - A) / 10)) if f >= A else 1.0)
        pct.set_alpha(ui * a_g)
        label.set_alpha(ui * a_g)
        for i, t in enumerate(letters):
            s = ease((f - A - 8 - i * 3) / 10)
            t.set_alpha(s * a_g)
            t.set_y(-4.62 - 0.25 * (1 - s))
        return dyn

    if "--preview" in sys.argv:
        for art in dyn:
            art.set_animated(False)
        for name, f in [("p30", int(DL * 0.30)), ("p70", int(DL * 0.70)),
                        ("p100", DL - 1), ("complete", B + 5)]:
            update(f)
            fig.savefig(f"loader_{name}.png", dpi=90, facecolor=BG)
            print("saved", f"loader_{name}.png")
        return

    if "--bench" in sys.argv:
        fig.canvas.draw()
        cache = fig.canvas.copy_from_bbox(fig.bbox)
        for name, f in [("drawing", 120), ("complete", B + 5)]:
            t = time.time()
            for j in range(10):
                update(f + j)
                fig.canvas.restore_region(cache)
                for art in dyn:
                    ax.draw_artist(art)
                fig.canvas.blit(fig.bbox)
            print(name, f"{(time.time() - t) * 100:.0f} ms/frame (blit)")
        return

    anim = FuncAnimation(fig, update, frames=None if download_state else TOTAL,
                         interval=33, blit=True, repeat=not bool(download_state), cache_frame_data=False)
    if "--save" in sys.argv:
        print("Saving faravahar_loader.gif ...")
        anim.save("faravahar_loader.gif", writer=PillowWriter(fps=30), dpi=70,
                  savefig_kwargs={"facecolor": BG})
    plt.show()


if __name__ == "__main__":
    main()
