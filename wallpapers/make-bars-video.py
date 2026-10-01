#!/usr/bin/env python3
"""Animated zexos-bars: the five huge bars of the Z move slowly, like a calm
music equalizer lying on its side. Each bar keeps its right end where it is
and lets its left end reach out and draw back, a little brighter when it is
long and a little dimmer when it is short. Every bar has its own slow rhythm,
and on top of that one soft wave runs down through the bars from top to
bottom. All of it is smooth sine motion, nothing jumps.

The video loops seamlessly: every rhythm repeats a whole number of times per
LOOP seconds, and frame 0 is the still picture (zexos-bars.jpg).

  python make-bars-video.py              # 3840x2160 -> zexos-bars.mp4
  python make-bars-video.py 1920 1080    # smaller, faster test render

Needs ffmpeg. Play it with mpvpaper (the Noctalia "Video Wallpaper" plugin).
"""
import importlib.util
import multiprocessing as mp
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) >= 3 else (3840, 2160)

# Borrow the drawing code from the still-wallpaper script, at our size.
sys.argv = [sys.argv[0], str(W), str(H)]
spec = importlib.util.spec_from_file_location("wp", HERE / "make-wallpapers.py")
wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
S = wp.S

LOOP = 12.0      # seconds before the video repeats
FPS = 30
PAL = wp.PALETTES["violet"]

# Same placement as bars() in make-wallpapers.py.
SIZE = 1500 * S
CX, CY = W * 0.66, H * 0.5
K = SIZE / 120                     # pixels per unit of the 120x120 logo grid

REACH = 4.0      # how far a bar's left end moves, in logo-grid units (x2 at most)
GLOW = 0.12      # how much brighter a bar gets at full reach
# Each bar's own rhythm: (beats per loop, starting phase). Whole numbers of
# beats per loop keep the loop seamless; mixing 2 and 3 keeps them out of step.
RHYTHM = [(2, 0.3), (3, 2.1), (2, 4.0), (3, 0.9), (2, 2.8)]
WAVE_STEP = 0.9  # phase delay of the travelling wave from one bar to the next


def level(t):
    """How far each bar reaches at time t: a -1..1-ish number per bar."""
    w = 2 * np.pi * t / LOOP
    return np.array([0.6 * np.sin(n * w + ph) + 0.4 * np.sin(w - WAVE_STEP * i)
                     for i, (n, ph) in enumerate(RHYTHM)])


LEVEL0 = level(0.0)


def bar_mask(t):
    """The bars as a smooth 0..1 mask, each weighted by its brightness.
    Drawn with a distance field instead of PIL so the edges are anti-aliased
    and the moving ends glide instead of stepping a whole pixel at a time."""
    lv = level(t) - LEVEL0             # 0 at frame 0, so frame 0 is the still
    m = np.zeros((H, W), np.float32)
    x0, y0 = CX - SIZE / 2, CY - SIZE / 2
    xs = np.arange(W, dtype=np.float32) + 0.5
    for (x, y, w, h, r), d in zip(wp.Z_RECTS, lv):
        ext = REACH * d                # left end moves, right end stays put
        left, right = x0 + (x - ext) * K, x0 + (x + w) * K
        top, bot = y0 + y * K, y0 + (y + h) * K
        rr = r * K
        r0, r1 = max(0, int(top) - 2), min(H, int(bot) + 3)
        ys = np.arange(r0, r1, dtype=np.float32)[:, None] + 0.5
        qx = np.abs(xs[None, :] - (left + right) / 2) - ((right - left) / 2 - rr)
        qy = np.abs(ys - (top + bot) / 2) - ((bot - top) / 2 - rr)
        dist = (np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
                + np.minimum(np.maximum(qx, qy), 0) - rr)
        cover = np.clip(0.5 - dist, 0, 1) * (1 + GLOW * d / 2)
        m[r0:r1] = np.maximum(m[r0:r1], cover)
    return m


def soft(mask, radius):
    """Blurred copy of the mask, done at a quarter size: same look, much faster."""
    # PIL only blurs 8-bit pictures; the mask can go a bit over 1, so squeeze
    # it into 0..255 with some headroom and scale it back afterwards.
    small = Image.fromarray(np.clip(mask / 1.2 * 255, 0, 255).astype(np.uint8))
    small = small.resize((W // 4, H // 4), Image.BILINEAR)
    small = small.filter(ImageFilter.GaussianBlur(radius / 4))
    return np.asarray(small.resize((W, H), Image.BILINEAR), np.float32) / 255 * 1.2


def frame(k):
    t = k / FPS
    m = bar_mask(t)[..., None]
    s = soft(m[..., 0], 60 * S)[..., None]
    # Same mix as bars(): see-through bars plus a soft glow around them.
    img = BG * (1 - m * 0.55) + GRAD * m * 0.55 + GRAD * s * 0.18 + BLOB
    img = img * VIG + GRAIN
    return np.clip(img, 0, 255).astype(np.uint8).tobytes()


def setup():
    """Everything that never moves, worked out once and shared with workers."""
    global BG, GRAD, BLOB, VIG, GRAIN
    BG = wp.hexrgb(PAL[0])
    GRAD = wp.logo_gradient(PAL[1], PAL[2], PAL[3], CX, CY, SIZE).astype(np.float32)
    BLOB = wp.blob(250, 900, 800, 500, PAL[1], 0.15).astype(np.float32)
    k = 0.4
    VIG = (1 - k * ((wp.xx - W / 2) ** 2 / (W / 2) ** 2
                    + (wp.yy - H / 2) ** 2 / (H / 2) ** 2))[..., None].astype(np.float32)
    GRAIN = np.random.default_rng(1).normal(0, 1.8, (H, W, 3)).astype(np.float32)


if __name__ == "__main__":
    out = HERE / "zexos-bars.mp4"
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
