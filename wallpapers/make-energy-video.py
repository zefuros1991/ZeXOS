#!/usr/bin/env python3
"""Animated zexos-topo-energy: little comets of green energy run along the
purple contour lines, then fade out, and the line goes back to purple behind
them. A slow, soft two-part swell (like a resting pulse, but far subtler)
nudges their brightness and speed so the picture feels alive.

The video loops seamlessly: every comet repeats exactly once per LOOP seconds.

  python make-energy-video.py              # 3840x2160 -> zexos-topo-energy.mp4
  python make-energy-video.py 1920 1080    # smaller, faster test render

Needs ffmpeg. Play it with mpvpaper (the Noctalia "Video Wallpaper" plugin).
"""
import importlib.util
import multiprocessing as mp
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

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
COMETS = 40      # how many comets take turns (about a third are on screen at once)
BEAT = 2.0       # seconds per swell: 6 per loop
PAL = wp.PALETTES["violet"]


def swell(phase):
    """One beat, 0..1 phase -> 0..1: a soft main rise and a smaller echo
    right after it, then rest. Wide, gentle bumps, not a sharp thump."""
    def bump(at, width):
        d = (phase - at + 0.5) % 1 - 0.5
        return np.exp(-(d / width) ** 2)
    return bump(0.10, 0.09) + 0.55 * bump(0.32, 0.10)


def timeline(n):
    """Per-frame brightness gain and a warped clock (`tau`) that runs a bit
    faster during each swell and a bit slower between. tau still covers
    exactly LOOP seconds per loop, so the loop stays seamless."""
    t = np.arange(n) / FPS
    s = swell((t / BEAT) % 1)
    s = (s - s.mean()) / (s.max() - s.mean())    # -something..1, mean 0
    gain = 1 + 0.14 * s
    speed = 1 + 0.22 * s
    tau = np.concatenate([[0], np.cumsum(speed[:-1])]) / FPS
    return gain, tau * LOOP / (speed.sum() / FPS)


def plan_comets():
    """Where each comet runs, when it starts and how long it lives."""
    levels, line = wp.topo_lines()
    rng = np.random.default_rng(21)
    comets = []
    starts = wp.line_starts(levels, line, COMETS, seed=17)
    for i, (x, y) in enumerate(starts):
        pts = wp.contour_path(levels, x, y, rng.uniform(380, 820) * S)
        if rng.random() < 0.5:
            pts = pts[::-1]                          # both directions of travel
        comets.append(dict(
            pts=pts,
            tail=max(8, int(len(pts) * rng.uniform(0.3, 0.45))),
            start=(i + rng.uniform(-0.3, 0.3)) * LOOP / len(starts),
            life=rng.uniform(4.0, 6.5),
            power=rng.uniform(0.85, 1.0),
        ))
    return comets


def soft_glow(mask, radius):
    """glow(), but blurred at a quarter size: same look, many times faster."""
    small = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    small = small.resize((W // 4, H // 4), Image.BILINEAR)
    small = small.filter(ImageFilter.GaussianBlur(radius * S / 4))
    return np.asarray(small.resize((W, H), Image.BILINEAR), np.float32) / 255


def frame(k):
    m = Image.new("L", (W, H), 0)
    for c in COMET_PLAN:
        age = (TAU[k] - c["start"]) % LOOP
        if age >= c["life"]:
            continue
        p = age / c["life"]
        n = len(c["pts"])
        head = p * (n + c["tail"])                 # runs in, along, and off the end
        fade = min(1, p / 0.12, (1 - p) / 0.2)     # appear and disappear softly
        layer = Image.new("L", (W, H), 0)
        wp.draw_streak(layer, c["pts"], head=head, tail=c["tail"], width=3.0)
        m = Image.fromarray(np.maximum(np.asarray(m), (np.asarray(layer) * fade * c["power"]).astype(np.uint8)))
    mask = np.asarray(m, np.float32) / 255 * KEEP_OUT * GAIN[k]
    col = wp.hexrgb(PAL[3])
    img = BASE * (1 - np.clip(mask, 0, 1)[..., None] * 0.85) + mask[..., None] * col * 0.95
    img += soft_glow(mask, 7)[..., None] * col * 1.8
    img += soft_glow(mask, 26)[..., None] * col * 1.0
    return np.clip(img, 0, 255).astype(np.uint8).tobytes()


if __name__ == "__main__":
    out = HERE / "zexos-topo-energy.mp4"
    frames = int(LOOP * FPS)
    print(f"Drawing {frames} frames at {W}x{H} into {out.name}")
    BASE = wp.topo(PAL).astype(np.float32)
    COMET_PLAN = plan_comets()
    GAIN, TAU = timeline(frames)
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.hypot(xx - W / 2, yy - H / 2) / S
    KEEP_OUT = np.clip((r - 190) / 110, 0, 1).astype(np.float32)  # none over the logo
    del yy, xx, r
    enc = subprocess.Popen([
        "ffmpeg", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(out)], stdin=subprocess.PIPE)
    # fork: workers share the big arrays above instead of copying them in
    with mp.get_context("fork").Pool(max(1, mp.cpu_count() - 2)) as pool:
        for i, data in enumerate(pool.imap(frame, range(frames), chunksize=2)):
            enc.stdin.write(data)
            if i % FPS == 0:
                print(f"  {i / FPS:4.0f}s / {LOOP:.0f}s", flush=True)
    enc.stdin.close()
    sys.exit(enc.wait())
