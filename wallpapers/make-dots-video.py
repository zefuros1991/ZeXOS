#!/usr/bin/env python3
"""Animated zexos-dots-forest: soft rings of light spread slowly outward from
the Z through the faint dot grid, like ripples on a pond. As a ring passes,
each dot swells a little and glows brighter, then settles back. Here and
there a single dot also twinkles gently on its own. The bright dots that
make up the Z itself never change, so the logo stays still and sharp.

The video loops seamlessly: the ripples and every twinkle repeat a whole
number of times per LOOP seconds.

  python make-dots-video.py              # 3840x2160 -> zexos-dots-forest.mp4
  python make-dots-video.py 1920 1080    # smaller, faster test render

Needs ffmpeg. Play it with mpvpaper (the Noctalia "Video Wallpaper" plugin).
"""
import importlib.util
import multiprocessing as mp
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) >= 3 else (3840, 2160)

# Borrow the drawing code from the still-wallpaper script, at our size.
sys.argv = [sys.argv[0], str(W), str(H)]
spec = importlib.util.spec_from_file_location("wp", HERE / "make-wallpapers.py")
wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
S = wp.S

LOOP = 12.0        # seconds before the video repeats
FPS = 30
PAL = wp.PALETTES["forest"]

STEP = 26 * S      # dot spacing, same as dots()
LOGO = 860 * S     # size of the Z the dots trace, same as dots()

RING_GAP = 520     # distance between ripple rings (pixels at 1920 wide)
RINGS = 1          # rings started per loop at each point: 1 = slowest drift
RING_WIDTH = 0.16  # how wide a ring is, as a share of RING_GAP
RIPPLE_GROW = 1.1  # extra dot radius at the top of a ring (pixels at 1920 wide)
RIPPLE_GLOW = 1.3  # extra brightness at the top of a ring (1 = twice as bright)

TWINKLE_SHARE = 0.05  # roughly 1 in 20 faint dots twinkles
TWINKLE_GLOW = 1.6    # extra brightness at the top of a twinkle


def setup():
    """Everything that never moves, worked out once and shared with workers.
    Follows dots() in make-wallpapers.py step by step, but keeps the parts
    apart so each frame only has to redraw the dots."""
    global CELL, RADIUS0, R, INSIDE, COLOUR, REST, VIG, CELL_DIST, TW_PHASE, TW_BEATS, TW_ON
    xx, yy = wp.xx, wp.yy
    gx = (xx % STEP) - STEP / 2
    gy = (yy % STEP) - STEP / 2
    R = np.hypot(gx, gy)
    col = np.floor(xx / STEP).astype(np.int32)
    row = np.floor(yy / STEP).astype(np.int32)
    cxs = (col + 0.5) * STEP
    cys = (row + 0.5) * STEP
    zm = wp.z_mask(LOGO, W / 2, H / 2, blur=6 * S)
    INSIDE = zm[np.clip(cys.astype(int), 0, H - 1), np.clip(cxs.astype(int), 0, W - 1)]
    RADIUS0 = (2.0 + 4.5 * INSIDE) * S
    grad = wp.logo_gradient(PAL[1], PAL[2], PAL[3], W / 2, H / 2, LOGO)
    faint = wp.hexrgb(PAL[1]) * 0.25
    COLOUR = (faint * (1 - INSIDE[..., None]) + grad * INSIDE[..., None]).astype(np.float32)

    # One number per dot (grid cell), looked up per pixel through CELL.
    rows, cols = row.max() + 1, col.max() + 1
    CELL = (row * cols + col).astype(np.int32)
    cr, cc = np.mgrid[0:rows, 0:cols]
    CELL_DIST = (np.hypot((cc + 0.5) * STEP - W / 2, (cr + 0.5) * STEP - H / 2) / S).ravel()
    rng = np.random.default_rng(31)
    TW_ON = (rng.random(rows * cols) < TWINKLE_SHARE).astype(np.float32)
    TW_PHASE = rng.uniform(0, 2 * np.pi, rows * cols)
    TW_BEATS = rng.choice([1, 2], rows * cols)      # once or twice per loop

    # The background, haze, vignette and grain do not move.
    k = 0.35
    VIG = (1 - k * ((xx - W / 2) ** 2 / (W / 2) ** 2
                    + (yy - H / 2) ** 2 / (H / 2) ** 2))[..., None].astype(np.float32)
    rest = wp.base(PAL[0]) + wp.blob(960, 540, 900, 520, PAL[2], 0.10)
    grain = np.random.default_rng(1).normal(0, 1.2, (H, W, 3)).astype(np.float32)
    REST = (rest * VIG + grain).astype(np.float32)


def lift(t):
    """Per dot, 0..about 1: how much the ripple and twinkles lift it at time t."""
    # Ripple: rings drift outward. Position inside the ring pattern, 0..1,
    # moves by RINGS whole steps per loop, so it lands back where it began.
    p = (CELL_DIST / RING_GAP - RINGS * t / LOOP) % 1
    d = (p + 0.5) % 1 - 0.5                          # distance to the nearest ring
    ring = np.exp(-(d / RING_WIDTH) ** 2)
    # Rings are born softly at the logo and fade out towards the edges.
    ring *= np.clip((CELL_DIST - 300) / 200, 0, 1) * np.clip(1.3 - CELL_DIST / 1200, 0.25, 1)
    # Twinkle: a short soft bump once or twice per loop, a few dots at a time.
    tw = np.clip(np.sin(TW_BEATS * 2 * np.pi * t / LOOP + TW_PHASE), 0, 1) ** 6 * TW_ON
    return ring, tw


def frame(k):
    t = k / FPS
    ring, tw = lift(t)
    ring, tw = ring[CELL], tw[CELL]
    out = 1 - INSIDE                                  # the Z's dots stay as they are
    radius = RADIUS0 + RIPPLE_GROW * S * ring * out
    dot = np.clip(radius - R + 0.8, 0, 1)
    bright = 1 + (RIPPLE_GLOW * ring + TWINKLE_GLOW * tw) * out
    img = REST + (dot * bright)[..., None] * COLOUR * VIG
    return np.clip(img, 0, 255).astype(np.uint8).tobytes()


if __name__ == "__main__":
    out = HERE / "zexos-dots-forest.mp4"
    frames = int(LOOP * FPS)
    print(f"Drawing {frames} frames at {W}x{H} into {out.name}")
    setup()
    enc = subprocess.Popen([
        "ffmpeg", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(out)], stdin=subprocess.PIPE)
    # fork: workers share the big arrays above instead of copying them in.
    # 5 workers at most, so other renders on the machine get their share.
    with mp.get_context("fork").Pool(5) as pool:
        for i, data in enumerate(pool.imap(frame, range(frames), chunksize=2)):
            enc.stdin.write(data)
            if i % FPS == 0:
                print(f"  {i / FPS:4.0f}s / {LOOP:.0f}s", flush=True)
    enc.stdin.close()
    sys.exit(enc.wait())
