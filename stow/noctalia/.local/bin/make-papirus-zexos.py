#!/usr/bin/env python3
"""Build Papirus-ZeXOS: Papirus with folders that follow the colour scheme.

Papirus draws its folders in fixed colours. KDE apps only recolour icons that
mark their colours with a class from the colour scheme (Breeze does this), and
Dolphin only redraws its icons when the colour palette changes. So this copies
Papirus' blue folders and swaps the blue for the scheme's accent colour. Every
wallpaper change changes the palette, and the folders follow it live.

Two sets are made per size:
  places-accent  folders in the accent colour (dark mode)
  places-light   Papirus' white folders (light mode, whose accent is black)
and <size>/places is a link to the one in use (see auto-theme-mode.sh).

auto-theme-mode.sh runs this on every wallpaper change. It only rebuilds when
Papirus was installed or updated since the last build, which it notes in
.papirus-stamp, so the new folder icons of a Papirus update are picked up.
"""
import os
import re
import sys

SRC = "/usr/share/icons/Papirus"
DATA = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
DEST = os.path.join(DATA, "icons", "Papirus-ZeXOS")
STYLE = ('<defs><style id="current-color-scheme" type="text/css">'
         '.ColorScheme-Accent { color:#5294e2; }</style></defs>')

# Papirus blue -> how dark to draw it over the accent colour (0 = accent itself).
SHADES = {"#5294e2": 0.0, "#4877b1": 0.2, "#1d344f": 0.65}
ELEMENT = re.compile(r"<(path|rect|circle|ellipse)\b[^>]*/>", re.S)
FILL = re.compile(r"fill:(#[0-9a-fA-F]{6})")
COLOUR_NAME = re.compile(r"^(folder|user)-blue(-.+)?\.svg$")


def recolour(svg):
    def swap(m):
        el = m.group(0)
        f = FILL.search(el)
        if not f or f.group(1).lower() not in SHADES:
            return el
        shade = SHADES[f.group(1).lower()]
        base = el.replace(f.group(0), "fill:currentColor", 1)
        base = base.replace("<" + m.group(1), "<%s class=\"ColorScheme-Accent\"" % m.group(1), 1)
        if not shade:
            return base
        # Same shape again in black, see-through, to darken the accent.
        dark = FILL.sub("fill:#000000;fill-opacity:%g" % shade, el, 1)
        return base + dark
    svg = ELEMENT.sub(swap, svg)
    return re.sub(r"(<svg\b[^>]*>)", r"\1" + STYLE, svg, count=1)


def build():
    for size in sorted(os.listdir(SRC)):
        places = os.path.join(SRC, size, "places")
        if not os.path.isdir(places):
            continue
        accent = os.path.join(DEST, size, "places-accent")
        light = os.path.join(DEST, size, "places-light")
        os.makedirs(accent, exist_ok=True)
        os.makedirs(light, exist_ok=True)
        for name in os.listdir(places):
            target = os.path.basename(os.path.realpath(os.path.join(places, name)))
            if not COLOUR_NAME.match(target):
                continue
            with open(os.path.join(places, target)) as f:
                blue = f.read()
            white_file = os.path.join(places, target.replace("-blue", "-white", 1))
            with open(white_file) as f:
                white = f.read()
            with open(os.path.join(accent, name), "w") as f:
                f.write(recolour(blue))
            with open(os.path.join(light, name), "w") as f:
                f.write(white)
        link = os.path.join(DEST, size, "places")
        if not os.path.islink(link):
            os.symlink("places-accent", link)

    with open(os.path.join(SRC, "index.theme")) as f:
        index = f.read()
    index = index.replace("Name=Papirus\n", "Name=Papirus-ZeXOS\n", 1)
    index = re.sub(r"^Inherits=.*$", "Inherits=Papirus,breeze,hicolor", index, count=1, flags=re.M)
    with open(os.path.join(DEST, "index.theme"), "w") as f:
        f.write(index)


def papirus_stamp():
    return str(os.stat(os.path.join(SRC, "index.theme")).st_mtime_ns)


def up_to_date(stamp):
    try:
        with open(os.path.join(DEST, ".papirus-stamp")) as f:
            return f.read() == stamp
    except OSError:
        return False


if not os.path.isfile(os.path.join(SRC, "index.theme")):
    sys.exit(0)  # Papirus isn't installed
stamp = papirus_stamp()
if not up_to_date(stamp):
    build()
    with open(os.path.join(DEST, ".papirus-stamp"), "w") as f:
        f.write(stamp)
