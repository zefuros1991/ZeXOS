#!/usr/bin/env python3
"""Animated zexos-aurora: the three glowing ribbons drift and sway like a
real aurora. Small ripples travel along each ribbon, the big wave rocks
gently from side to side, and the brightness breathes softly along its
length. Each ribbon keeps its own slow rhythm, so they never move in step.

The video loops seamlessly: every motion repeats exactly once per LOOP seconds.
Frame 0 is the still picture, with only a faint shimmer added.

  python make-aurora-video.py                    # all three, 3840x2160
  python make-aurora-video.py 1920 1080          # smaller, faster test render
  python make-aurora-video.py 1920 1080 zexos-aurora-ocean   # just one

Makes zexos-aurora.mp4 (violet), zexos-aurora-ocean.mp4 and
zexos-aurora-mono.mp4, the moving versions of the .jpg stills with the same
names. Needs ffmpeg. Play it with mpvpaper (the Noctalia "Video Wallpaper" plugin).
"""
import importlib.util
import multiprocessing as mp
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
args = sys.argv[1:]
if len(args) >= 2 and args[0].isdigit() and args[1].isdigit():
    W, H = int(args[0]), int(args[1])
    args = args[2:]
else:
    W, H = 3840, 2160
ONLY = set(args)

# Borrow the drawing code from the still-wallpaper script, at our size.
sys.argv = [sys.argv[0], str(W), str(H)]
spec = importlib.util.spec_from_file_location("wp", HERE / "make-wallpapers.py")
wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
S = wp.S

LOOP = 12.0      # seconds before the video repeats
FPS = 30

# Which stills get a moving version, and in which colours (same as PLAN).
VIDEOS = [("zexos-aurora", "violet"), ("zexos-aurora-ocean", "ocean"),
          ("zexos-aurora-mono", "mono")]

# The three ribbons, exactly as aurora() in make-wallpapers.py draws them:
# colour index, height, wave size, thickness, strength.
RIBBONS = [(1, 420, 120, 90, 0.9), (2, 520, 90, 70, 0.6), (3, 640, 140, 80, 0.75)]

# How each ribbon moves. Whole numbers are "times per loop", which is what
# keeps the loop seamless. Kept small on purpose: calm, not busy.
#   ripple: which way (and how many times) the small ripples run along it
#   sway / sway_amp: how often and how far (radians) the big wave rocks
#   rise: how far (px at 1920 wide) the whole ribbon floats up and down
#   breath: how often the bright stretch slides along it
MOTION = [dict(ripple=1, sway=1, sway_amp=0.28, rise=14, breath=1, at=0.0),
          dict(ripple=-1, sway=2, sway_amp=0.18, rise=10, breath=1, at=2.1),
          dict(ripple=1, sway=1, sway_amp=0.24, rise=18, breath=2, at=4.2)]

x = np.arange(W, dtype=np.float32)[None, :]
y = np.arange(H, dtype=np.float32)[:, None]


def still_parts(pal):
    """Everything in the still that does not move: background, the two big
    soft blobs, the vignette and the grain. Rebuilt the same way aurora()
    does it (same grain seed), so frame 0 matches the .jpg."""
    v = 1 - 0.35 * ((wp.xx - W / 2) ** 2 / (W / 2) ** 2 + (wp.yy - H / 2) ** 2 / (H / 2) ** 2)
    v = v[..., None]
    back = wp.base(pal[0]) + wp.blob(300, 150, 700, 400, pal[1], 0.25) \
        + wp.blob(1700, 1000, 700, 400, pal[3], 0.2)
    noise = np.random.default_rng(1).normal(0, 2.2, (H, W, 3)).astype(np.float32)
    return back * v + noise, v


def frame(k):
    p = 2 * np.pi * k / FPS / LOOP           # 0..2pi over one loop
    img = STATIC.copy()
    for i, ((ci, off, amp, thick, a), m) in enumerate(zip(RIBBONS, MOTION)):
        # Every term below is zero at p = 0, so frame 0 is the still.
        sway = m["sway_amp"] * (np.sin(m["sway"] * p + m["at"]) - np.sin(m["at"]))
        rise = m["rise"] * np.sin(p + m["at"] + 1.0) - m["rise"] * np.sin(m["at"] + 1.0)
        c = (off + rise
             + amp * np.sin(x / W * 2.4 * np.pi + i * 1.3 + sway)
             + 40 * np.sin(x / W * 6 * np.pi + i - m["ripple"] * p)) * S
        # The bright stretch slides a little back and forth along the ribbon,
        # and a faint shimmer travels along it.
        drift = 0.25 * (np.sin(m["breath"] * p + m["at"]) - np.sin(m["at"]))
        light = 0.35 + 0.65 * np.clip(np.sin(x / W * np.pi + 0.2 * i + drift), 0, 1)
        light = light * (1 + 0.08 * np.sin(x / W * 4 * np.pi - p + m["at"]) * np.sin(p / 2) ** 2)
        band = np.exp(-((y - c) / (thick * S)) ** 2) * light
        img += (band * (a * 0.8))[..., None] * (wp.hexrgb(PAL[ci]) * VIG)
    return np.clip(img, 0, 255).astype(np.uint8).tobytes()


def render(name, pal_name):
    global PAL, STATIC, VIG
    PAL = wp.PALETTES[pal_name]
    STATIC, VIG = still_parts(PAL)
    out = HERE / f"{name}.mp4"
    frames = int(LOOP * FPS)
    print(f"Drawing {frames} frames at {W}x{H} into {out.name}")
    enc = subprocess.Popen([
        "ffmpeg", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(out)], stdin=subprocess.PIPE)
    # fork: workers share the big arrays above instead of copying them in.
    # Five workers at most: other renders may be running at the same time.
    with mp.get_context("fork").Pool(5) as pool:
        for i, data in enumerate(pool.imap(frame, range(frames), chunksize=2)):
            enc.stdin.write(data)
            if i % FPS == 0:
                print(f"  {i / FPS:4.0f}s / {LOOP:.0f}s", flush=True)
    enc.stdin.close()
    return enc.wait()


if __name__ == "__main__":
    rc = 0
    for name, pal_name in VIDEOS:
        if not ONLY or name in ONLY:
            rc |= render(name, pal_name)
    sys.exit(rc)
