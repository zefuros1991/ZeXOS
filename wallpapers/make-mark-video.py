#!/usr/bin/env python3
"""Animated zexos-mark: the glowing Z logo over its soft two-colour haze,
brought gently to life. The logo itself never moves and stays sharp:

  - its glow breathes: a slow swell and settle, three times per loop
  - once per loop a soft light sheen slides across the logo, corner to
    corner, the same diagonal way the logo's colour gradient runs
  - the two colour clouds behind it drift very slowly in small circles

The video loops seamlessly: every motion repeats exactly once per LOOP seconds,
and the first frame looks just like the still picture.

  python make-mark-video.py                          # 3840x2160, every colour below
  python make-mark-video.py 1920 1080                # smaller, faster test render
  python make-mark-video.py 3840 2160 zexos-mark-light   # just one of them

Needs ffmpeg. Play it with mpvpaper (the Noctalia "Video Wallpaper" plugin).
"""
import importlib.util
import multiprocessing as mp
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) >= 3 else (3840, 2160)
ONLY = set(sys.argv[3:])

# Borrow the drawing code from the still-wallpaper script, at our size.
sys.argv = [sys.argv[0], str(W), str(H)]
spec = importlib.util.spec_from_file_location("wp", HERE / "make-wallpapers.py")
wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
S = wp.S

LOOP = 12.0       # seconds before the video repeats
FPS = 30
BREATHS = 3       # glow swells per loop (one every 4 seconds)
SHEEN_AT = 4.5    # second the sheen starts its trip across the logo...
SHEEN_FOR = 3.5   # ...and how long the trip takes
DRIFT = 60        # how far (in 1920-wide pixels) the haze clouds wander

# Which stills get a video: (name, colour set). Same names as make-wallpapers.py.
VIDEOS = [
    ("zexos-mark-ember", "ember"),
    ("zexos-mark-light", "light"),
]


def breath(t):
    """0..1, starts and ends at 0: a slow swell and settle, BREATHS per loop."""
    return 0.5 - 0.5 * np.cos(2 * np.pi * BREATHS * t / LOOP)


def sheen_pos(t):
    """Where the sheen is, measured along the logo gradient (0 = top-left
    corner of the logo, 1 = bottom-right). It waits off the logo, eases
    across it once, and waits off the other side, so the jump back at the
    end of the loop happens where nobody can see it."""
    p = np.clip((t - SHEEN_AT) / SHEEN_FOR, 0, 1)
    p = p * p * (3 - 2 * p)                       # ease in and out
    return -0.6 + 2.2 * p


class Mark:
    """Everything that does not change between frames, worked out once."""

    def __init__(self, pal):
        self.pal = pal
        self.light = pal[0] == wp.PALETTES["light"][0]
        self.size = 170 * S
        cx, cy = W / 2, H / 2
        self.grad = wp.logo_gradient(pal[1], pal[2], pal[3], cx, cy, self.size).astype(np.float32)
        halo = wp.z_mask(self.size, cx, cy, blur=self.size * 0.25)[..., None]
        self.glow = 0.25 if self.light else 0.55
        # On the pale background a glow change is harder to see, so it breathes deeper.
        self.swell = 0.6 if self.light else 0.4
        self.halo = (halo * self.grad).astype(np.float32)
        self.logo = wp.z_mask(self.size, cx, cy)[..., None].astype(np.float32)
        # Distance along the logo's diagonal, same measure as logo_gradient().
        self.u = (((wp.xx - cx) + (wp.yy - cy)) / (self.size * 1.4) + 0.5).astype(np.float32)
        self.vig = None if self.light else (
            1 - 0.3 * ((wp.xx - W / 2) ** 2 / (W / 2) ** 2 + (wp.yy - H / 2) ** 2 / (H / 2) ** 2)
        )[..., None].astype(np.float32)
        self.grain = np.random.default_rng(1).normal(0, 1.6, (H, W, 3)).astype(np.float32)
        # The haze is so smooth it can be drawn at quarter size and scaled up.
        self.qh, self.qw = H // 4, W // 4
        qy, qx = np.mgrid[0:self.qh, 0:self.qw].astype(np.float32)
        self.qx, self.qy = (qx + 0.5) * W / self.qw, (qy + 0.5) * H / self.qh

    def haze(self, t):
        """The two colour clouds of mark(), each wandering on its own small
        loop (they start exactly where the still has them)."""
        ph = 2 * np.pi * t / LOOP
        pal, light = self.pal, self.light
        out = np.zeros((self.qh, self.qw, 3), np.float32)
        for cx, cy, dx, dy, col, a in [
            (500, 250, np.sin(ph), 1 - np.cos(ph), pal[1], 0.10 if light else 0.18),
            (1500, 900, -np.sin(ph), np.cos(ph) - 1, pal[3], 0.08 if light else 0.14),
        ]:
            cx, cy = (cx + DRIFT * dx) * S, (cy + 0.6 * DRIFT * dy) * S
            d = ((self.qx - cx) / (900 * S)) ** 2 + ((self.qy - cy) / (500 * S)) ** 2
            out += np.exp(-d)[..., None] * wp.hexrgb(col) * a
        big = [np.asarray(Image.fromarray(out[..., c]).resize((W, H), Image.BILINEAR))
               for c in range(3)]
        return np.stack(big, -1)

    def frame(self, t):
        img = wp.hexrgb(self.pal[0]) + self.haze(t)
        if self.light:
            img = img * 0.93 + wp.hexrgb(self.pal[0]) * 0.07
        b = breath(t)
        img += self.halo * (self.glow * (1 + self.swell * b))
        # The sheen: a soft band of light lying across the logo's diagonal.
        band = np.exp(-((self.u - sheen_pos(t)) / 0.09) ** 2)[..., None]
        face = self.grad + (255 - self.grad) * band * 0.38
        img = img * (1 - self.logo) + face * self.logo
        # A touch of the sheen spills into the glow just around the logo.
        img += self.halo * band * (0.12 if self.light else 0.18)
        if self.vig is not None:
            img = img * self.vig
        img += self.grain
        return np.clip(img, 0, 255).astype(np.uint8)


def frame(k):
    return MARK.frame(k / FPS).tobytes()


def render(name, palname):
    global MARK
    out = HERE / f"{name}.mp4"
    frames = int(LOOP * FPS)
    print(f"Drawing {frames} frames at {W}x{H} into {out.name}")
    MARK = Mark(wp.PALETTES[palname])
    enc = subprocess.Popen([
        "ffmpeg", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(out)], stdin=subprocess.PIPE)
    # fork: workers share the big arrays above instead of copying them in
    with mp.get_context("fork").Pool(5) as pool:
        for i, data in enumerate(pool.imap(frame, range(frames), chunksize=2)):
            enc.stdin.write(data)
            if i % FPS == 0:
                print(f"  {i / FPS:4.0f}s / {LOOP:.0f}s", flush=True)
    enc.stdin.close()
    if enc.wait():
        sys.exit(f"ffmpeg failed on {out.name}")


if __name__ == "__main__":
    for name, palname in VIDEOS:
        if not ONLY or name in ONLY:
            render(name, palname)
