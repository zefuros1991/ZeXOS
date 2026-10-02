#!/usr/bin/env python3
"""Draw the avatars, the round picture above the login box: one for each
colour set of the ZeXOS wallpapers (avatar-violet.jpg, avatar-ocean.jpg ...).

Pixie always shows its own assets/avatar.jpg: it only takes a user's picture
from SDDM when the file name ends in .jpg/.png/..., and SDDM's user pictures
are called *.face.icon, so they never match. The package puts this file there.

What Pixie expects (from its README and Main.qml, v3.0): a square JPEG,
512x512 like the one it ships. It is drawn 120 pixels wide and cut to a
circle, so anything near the corners is never seen and the logo has to fit
well inside the circle.

The package turns Pixie's assets/avatar.jpg into a link to
/var/lib/sddm-wallpaper/avatar.jpg, and sync-sddm-wallpaper.sh copies the
avatar that matches your wallpaper there, next to the login wallpaper.

The logo is drawn fresh from docs/logo/zexos-mark.svg, not cut out of a
wallpaper, so it stays sharp. Only needed if you want to redraw it; the
finished avatars are already here:

    python packaging/pixie-sddm-zexos/make-avatar.py

Needs python-numpy and python-pillow, like wallpapers/make-wallpapers.py.
"""
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
LOGO = HERE.parent.parent / "docs/logo/zexos-mark.svg"
SIZE = 512          # what Pixie ships
SS = 4              # draw 4x bigger, then shrink, for smooth edges
# The colour sets of the wallpapers (the same as wallpapers/make-wallpapers.py):
# background, then the three logo colours.
PALETTES = {
    "violet": ("#12101c", "#7C5CFF", "#B45CE6", "#3DDC97"),  # the ZeXOS colours
    "ocean":  ("#0b1220", "#2F80ED", "#23B5D3", "#7CF4E1"),
    "ember":  ("#1a0f0e", "#FF6B4A", "#E6457A", "#FFC857"),
    "forest": ("#0d1612", "#2E9E6B", "#6CCB5F", "#D4E86A"),
    "mono":   ("#111214", "#8A8F98", "#C9CDD4", "#F2F3F5"),
    "light":  ("#ECE9F5", "#7C5CFF", "#B45CE6", "#2FB57E"),
}
LOGO_BOX = 0.54     # logo width as a share of the picture: its corners stay inside the circle


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def logo_rects():
    """The rounded bars from the SVG, on its 120x120 grid."""
    svg = LOGO.read_text()
    rects = []
    for attrs in re.findall(r"<rect ([^>]*)/>", svg):
        a = dict(re.findall(r'(\w+)="([^"]*)"', attrs))
        rects.append(tuple(float(a[k]) for k in ("x", "y", "width", "height", "rx")))
    return rects


def draw(name, pal):
    BG, C1, C2, C3 = pal
    light = name == "light"
    n = SIZE * SS
    rects = logo_rects()
    left = min(r[0] for r in rects)
    right = max(r[0] + r[2] for r in rects)
    top = min(r[1] for r in rects)
    bottom = max(r[1] + r[3] for r in rects)
    k = LOGO_BOX * n / (right - left)
    x0 = n / 2 - (left + right) / 2 * k
    y0 = n / 2 - (top + bottom) / 2 * k

    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)
    for x, y, w, h, r in rects:
        d.rounded_rectangle([x0 + x * k, y0 + y * k, x0 + (x + w) * k, y0 + (y + h) * k],
                            radius=r * k, fill=255)

    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    # Same diagonal violet -> pink -> green gradient as the SVG.
    t = np.clip(((xx - x0 - left * k) + (yy - y0 - top * k)) / ((right - left + bottom - top) * k), 0, 1)[..., None]
    a, b, c = hexrgb(C1), hexrgb(C2), hexrgb(C3)
    grad = np.where(t < 0.5, a + (b - a) * (t / 0.5), b + (c - b) * ((t - 0.5) / 0.5))

    # The background with a soft light in the first colour behind the logo,
    # like the wallpapers. On the light set the glow tints instead of adding
    # light, which would only wash it out to white.
    r2 = ((xx - n / 2) ** 2 + (yy - n / 2) ** 2) / (n / 2) ** 2
    img = np.zeros((n, n, 3), np.float32) + hexrgb(BG)
    glow = np.exp(-r2 * 1.6)[..., None]
    halo = np.asarray(mask.filter(ImageFilter.GaussianBlur(n * 0.06)), np.float32)[..., None] / 255
    if light:
        img += (hexrgb(C1) - img) * glow * 0.12
        img += (grad - img) * halo * 0.3
    else:
        img += glow * hexrgb(C1) * 0.22
        img += halo * grad * 0.5
    m = np.asarray(mask, np.float32)[..., None] / 255
    img = img * (1 - m) + grad * m

    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((SIZE, SIZE), Image.LANCZOS)
    path = HERE / f"avatar-{name}.jpg"
    out.save(path, quality=92, optimize=True)
    print(path)


def main():
    for name, pal in PALETTES.items():
        draw(name, pal)


if __name__ == "__main__":
    main()
