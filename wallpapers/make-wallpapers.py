#!/usr/bin/env python3
"""Draw the ZeXOS wallpapers.

Every wallpaper in this folder comes from this script: no photos, no
downloads, just maths. Run it again to redraw them all:

    python wallpapers/make-wallpapers.py            # 3840x2160 (4K)
    python wallpapers/make-wallpapers.py 2560 1440  # another size

Needs python-numpy and python-pillow (`sudo pacman -S python-numpy python-pillow`).
Only needed if you want to redraw them; the finished pictures are already here.

Styles (each comes in several colour sets, like CachyOS does with its own):
  aurora  - soft glowing ribbons. zexos-aurora.jpg is the default wallpaper.
  mark    - the ZeXOS "Z" logo, small and glowing, in the middle.
  topo    - map-style contour lines with the Z logo on top.
  bars    - the Z logo blown up huge, so only its bars cross the screen.
  dots    - a grid of dots; the dots inside the Z shine brighter.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent
W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) == 3 else (3840, 2160)
S = W / 1920  # every size below was designed at 1920 wide, then scaled


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


# Colour sets: background, then three accent colours (the logo gradient order).
PALETTES = {
    "violet": ("#12101c", "#7C5CFF", "#B45CE6", "#3DDC97"),  # the ZeXOS colours
    "ocean":  ("#0b1220", "#2F80ED", "#23B5D3", "#7CF4E1"),
    "ember":  ("#1a0f0e", "#FF6B4A", "#E6457A", "#FFC857"),
    "forest": ("#0d1612", "#2E9E6B", "#6CCB5F", "#D4E86A"),
    "mono":   ("#111214", "#8A8F98", "#C9CDD4", "#F2F3F5"),
    "light":  ("#ECE9F5", "#7C5CFF", "#B45CE6", "#2FB57E"),
}

# The ZeXOS logo: five rounded bars on a 120x120 grid (docs/logo/zexos-mark.svg).
Z_RECTS = [(18, 18, 84, 18, 5), (72, 41, 30, 11, 4), (46, 54.5, 30, 11, 4),
           (20, 68, 30, 11, 4), (18, 84, 84, 18, 5)]

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)


def base(bg):
    return np.zeros((H, W, 3), np.float32) + hexrgb(bg)


def blob(cx, cy, rx, ry, col, a):
    d = ((xx - cx * S) / (rx * S)) ** 2 + ((yy - cy * S) / (ry * S)) ** 2
    return np.exp(-d)[..., None] * hexrgb(col) * a


def vignette(img, k=0.35):
    v = 1 - k * ((xx - W / 2) ** 2 / (W / 2) ** 2 + (yy - H / 2) ** 2 / (H / 2) ** 2)
    return img * v[..., None]


def grain(img, amount=2.0, seed=1):
    # A little noise stops smooth gradients from showing colour steps.
    return img + np.random.default_rng(seed).normal(0, amount, img.shape).astype(np.float32)


def z_mask(size, cx, cy, blur=0):
    """Logo shape as a 0..1 mask, `size` pixels wide, centred at (cx, cy)."""
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    k = size / 120
    x0, y0 = cx - size / 2, cy - size / 2
    for x, y, w, h, r in Z_RECTS:
        d.rounded_rectangle([x0 + x * k, y0 + y * k, x0 + (x + w) * k, y0 + (y + h) * k],
                            radius=r * k, fill=255)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(m, np.float32) / 255


def logo_gradient(c1, c2, c3, cx, cy, size):
    """Diagonal three-colour gradient across the logo, like the SVG."""
    t = np.clip(((xx - cx) + (yy - cy)) / (size * 1.4) + 0.5, 0, 1)[..., None]
    a, b, c = hexrgb(c1), hexrgb(c2), hexrgb(c3)
    return np.where(t < 0.5, a + (b - a) * (t / 0.5), b + (c - b) * ((t - 0.5) / 0.5))


def put_logo(img, pal, size, cx=None, cy=None, glow=0.55, alpha=1.0):
    cx = W / 2 if cx is None else cx
    cy = H / 2 if cy is None else cy
    grad = logo_gradient(pal[1], pal[2], pal[3], cx, cy, size)
    halo = z_mask(size, cx, cy, blur=size * 0.25)[..., None]
    img = img + halo * grad * glow
    m = z_mask(size, cx, cy)[..., None] * alpha
    return img * (1 - m) + grad * m


def smooth_noise(scale, seed):
    """Soft random hills: blurred white noise, done in the frequency domain."""
    rng = np.random.default_rng(seed)
    n = rng.normal(size=(H, W)).astype(np.float32)
    fy = np.fft.fftfreq(H)[:, None]
    fx = np.fft.rfftfreq(W)[None, :]
    f = np.exp(-(fx ** 2 + fy ** 2) * (scale * S) ** 2)
    out = np.fft.irfft2(np.fft.rfft2(n) * f, s=(H, W)).astype(np.float32)
    return (out - out.mean()) / out.std()


def save(img, name):
    path = OUT / f"{name}.jpg"
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(path, quality=90, optimize=True)
    print(f"  {path.name}")


# ---------------------------------------------------------------- styles

def aurora(pal):
    """The README wallpaper: three wavy glowing ribbons."""
    img = base(pal[0])
    for i, (col, off, amp, thick, a) in enumerate([(pal[1], 420, 120, 90, 0.9),
                                                   (pal[2], 520, 90, 70, 0.6),
                                                   (pal[3], 640, 140, 80, 0.75)]):
        c = (off + amp * np.sin(xx / W * 2.4 * np.pi + i * 1.3) + 40 * np.sin(xx / W * 6 * np.pi + i)) * S
        band = np.exp(-((yy - c) / (thick * S)) ** 2) * (0.35 + 0.65 * np.clip(np.sin(xx / W * np.pi + 0.2 * i), 0, 1))
        img += band[..., None] * hexrgb(col) * a * 0.8
    img += blob(300, 150, 700, 400, pal[1], 0.25) + blob(1700, 1000, 700, 400, pal[3], 0.2)
    return grain(vignette(img), 2.2)


def mark(pal):
    """Just the logo, glowing, over a soft two-colour haze."""
    light = pal[0] == PALETTES["light"][0]
    img = base(pal[0])
    img += blob(500, 250, 900, 500, pal[1], 0.10 if light else 0.18)
    img += blob(1500, 900, 900, 500, pal[3], 0.08 if light else 0.14)
    if light:
        img = img * 0.93 + hexrgb(pal[0]) * 0.07
    img = put_logo(img, pal, 170 * S, glow=0.25 if light else 0.55)
    return grain(img if light else vignette(img, 0.3), 1.6)


def topo_lines():
    """The contour map: height field (in line units) and the 0..1 line mask."""
    field = smooth_noise(260, seed=7) * 0.5 + smooth_noise(700, seed=3) * 1.5
    levels = field * 7
    frac = np.abs(levels - np.round(levels))
    grad = np.hypot(*np.gradient(levels))  # keeps line width even on steep slopes
    line = np.clip(1.5 - frac / (grad + 1e-6) / (1.1 * S), 0, 1)
    return levels, line


def glow(mask, radius):
    """Soft halo around a 0..1 mask."""
    m = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    return np.asarray(m.filter(ImageFilter.GaussianBlur(radius * S)), np.float32) / 255


def contour_path(levels, x, y, length, step=1.5):
    """Points along the contour line through (x, y), `length` pixels long,
    centred on the start point. Walks the direction that keeps the height
    the same (at right angles to the slope), so it follows one line."""
    gy, gx = np.gradient(levels)

    def tangent(px, py):
        i = int(np.clip(py, 0, H - 1)); j = int(np.clip(px, 0, W - 1))
        tx, ty = -gy[i, j], gx[i, j]
        n = np.hypot(tx, ty) + 1e-9
        return tx / n, ty / n

    def walk(sign):
        pts, px, py = [], x, y
        for _ in range(int(length / 2 / (step * S))):
            tx, ty = tangent(px, py)
            mx, my = px + sign * tx * step * S / 2, py + sign * ty * step * S / 2
            tx, ty = tangent(mx, my)            # midpoint step: stays on the line
            px, py = px + sign * tx * step * S, py + sign * ty * step * S
            if not (0 <= px < W and 0 <= py < H):
                break
            pts.append((px, py))
        return pts
    return walk(-1)[::-1] + [(x, y)] + walk(1)


def line_starts(levels, line, n, seed, margin=0.04, band=0.13, clear=260):
    """n random points sitting right on a contour line, none within `clear`
    pixels (at 1920 wide) of the logo in the middle. `band` keeps them off the
    top and bottom strips an ultrawide (21:9) screen crops away."""
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(line[::4, ::4] > 0.95)
    keep = (xs * 4 > W * margin) & (xs * 4 < W * (1 - margin)) & (ys * 4 > H * band) & (ys * 4 < H * (1 - band))
    keep &= np.hypot(xs * 4 - W / 2, ys * 4 - H / 2) > clear * S
    xs, ys = xs[keep] * 4, ys[keep] * 4
    # One point per cell of a grid, so the streaks spread over the whole
    # picture instead of bunching up where the lines happen to be dense.
    cols = max(1, round((n * W / H) ** 0.5))
    rows = -(-n // cols)
    top, tall = H * band, H * (1 - 2 * band)
    cell = (np.minimum(xs * cols // W, cols - 1) * rows
            + np.minimum(((ys - top) * rows // tall).astype(int), rows - 1))
    cells = [c for c in rng.permutation(cols * rows) if (cell == c).any()]
    pts = []
    for c in cells[:n]:
        i = rng.choice(np.nonzero(cell == c)[0])
        pts.append((float(xs[i]), float(ys[i])))
    return pts


def draw_streak(mask, pts, head=None, tail=None, width=2.2):
    """Paint a streak on a PIL "L" canvas: brightest in the middle (or at
    `head`, a point index, fading back over `tail` points), dark at the ends."""
    d = ImageDraw.Draw(mask)
    n = len(pts)
    for k in range(n - 1):
        if head is None:
            v = np.sin(np.pi * k / max(n - 1, 1)) ** 1.5
        else:
            back = head - k
            v = 0.0 if back < 0 or back > tail else (1 - back / tail) ** 1.6
        if v > 0.01:
            d.line([pts[k], pts[k + 1]], fill=int(255 * v), width=max(1, round(width * S)))


def energy_layer(img, mask, col, core=0.95, halo=0.9):
    """Lay a 0..1 streak mask onto the picture as glowing colour."""
    col = hexrgb(col)
    img = img * (1 - mask[..., None] * 0.85) + mask[..., None] * col * core
    img += glow(mask, 7)[..., None] * col * halo
    img += glow(mask, 26)[..., None] * col * halo * 0.6
    return img


ENERGY_STREAKS = 28
ENERGY_HALO = 1.2


def topo_energy(pal):
    """topo, plus a few stretches of contour line lit up in the third (green)
    colour, like energy running through the map. Kept scarce on purpose:
    purple stays the mood, the green is an accent spread over the picture."""
    img = topo(pal)
    levels, line = topo_lines()
    m = Image.new("L", (W, H), 0)
    rng = np.random.default_rng(5)
    for x, y in line_starts(levels, line, ENERGY_STREAKS, seed=13):
        draw_streak(m, contour_path(levels, x, y, rng.uniform(120, 300) * S))
    return energy_layer(img, np.asarray(m, np.float32) / 255, pal[3], halo=ENERGY_HALO)


def topo(pal):
    """Contour lines like a hiking map, with the logo in the middle."""
    img = base(pal[0])
    levels, line = topo_lines()
    tint = hexrgb(pal[1]) * 0.55 + hexrgb(pal[2]) * 0.45
    img += line[..., None] * tint * 0.35
    img += blob(960, 540, 700, 420, pal[1], 0.12)
    img = put_logo(img, pal, 130 * S, glow=0.45)
    return grain(vignette(img, 0.3), 1.4)


def bars(pal):
    """The logo so big that only its bars fit: bold diagonal-ish stripes."""
    img = base(pal[0])
    size = 1500 * S
    cx, cy = W * 0.66, H * 0.5
    grad = logo_gradient(pal[1], pal[2], pal[3], cx, cy, size)
    m = z_mask(size, cx, cy)[..., None]
    soft = z_mask(size, cx, cy, blur=60 * S)[..., None]
    # Bars are see-through so the background glows through them a bit.
    img = img * (1 - m * 0.55) + grad * m * 0.55 + grad * soft * 0.18
    img += blob(250, 900, 800, 500, pal[1], 0.15)
    return grain(vignette(img, 0.4), 1.8)


def dots(pal):
    """A dot grid. Dots inside the Z are big and bright; the rest are faint."""
    img = base(pal[0])
    step = 26 * S
    gx = (xx % step) - step / 2
    gy = (yy % step) - step / 2
    r = np.hypot(gx, gy)
    # Sample the logo mask at each dot's centre so dots are whole, not cut.
    cxs = (np.floor(xx / step) + 0.5) * step
    cys = (np.floor(yy / step) + 0.5) * step
    zm = z_mask(860 * S, W / 2, H / 2, blur=6 * S)
    inside = zm[np.clip(cys.astype(int), 0, H - 1), np.clip(cxs.astype(int), 0, W - 1)]
    radius = (2.0 + 4.5 * inside) * S
    dot = np.clip(radius - r + 0.8, 0, 1)
    grad = logo_gradient(pal[1], pal[2], pal[3], W / 2, H / 2, 860 * S)
    faint = hexrgb(pal[1]) * 0.25
    img += dot[..., None] * (faint * (1 - inside[..., None]) + grad * inside[..., None])
    img += blob(960, 540, 900, 520, pal[2], 0.10)
    return grain(vignette(img, 0.35), 1.2)


# Which colour sets each style is drawn in. The first file is the default.
PLAN = [
    ("zexos-aurora", aurora, "violet"),
    ("zexos-aurora-ocean", aurora, "ocean"),
    ("zexos-aurora-ember", aurora, "ember"),
    ("zexos-aurora-forest", aurora, "forest"),
    ("zexos-aurora-mono", aurora, "mono"),
    ("zexos-mark", mark, "violet"),
    ("zexos-mark-ocean", mark, "ocean"),
    ("zexos-mark-ember", mark, "ember"),
    ("zexos-mark-light", mark, "light"),
    ("zexos-topo", topo, "violet"),
    ("zexos-topo-ember", topo, "ember"),
    ("zexos-topo-energy", topo_energy, "violet"),
    ("zexos-bars", bars, "violet"),
    ("zexos-bars-ocean", bars, "ocean"),
    ("zexos-dots", dots, "violet"),
    ("zexos-dots-forest", dots, "forest"),
]

if __name__ == "__main__":
    only = set(sys.argv[3:])
    print(f"Drawing {W}x{H} wallpapers into {OUT}")
    for name, style, pal in PLAN:
        if not only or name in only:
            save(style(PALETTES[pal]), name)
