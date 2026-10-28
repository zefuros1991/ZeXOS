"""The ZeXOS - Welcome window (PySide6 / Qt Widgets).

Layout follows the approved design (specs: design/project/Main.dc.html):
sidebar with the pages, content on the right, a bottom bar with About and
"Show at startup". Every colour comes from the Qt palette, which ZeXOS
sets from the wallpaper through qt6ct; when the wallpaper changes, Qt sends
a palette change and the window restyles itself while open.
"""
import json
import os
import shutil
import subprocess
import sys

from PySide6.QtCore import (QEasingCurve, QEvent, QPoint, QPointF, QProcess, QPropertyAnimation, QRect, QRectF, QSize, Qt, QTimer, QUrl,
                            Property)
from PySide6.QtGui import QColor, QPen, QDesktopServices, QFont, QFontDatabase, QIcon, QPainter, QPalette, QPixmap
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtWidgets import (QAbstractButton, QApplication, QBoxLayout, QDialog, QLayout, QFrame, QGridLayout, QHBoxLayout, QLabel,
                               QMainWindow, QPushButton, QScrollArea, QSizePolicy, QStackedWidget, QTextBrowser,
                               QVBoxLayout, QWidget)

from . import core
from .keys import KEYS, NOT_INSTALLED, command

TITLE = "ZeXOS - Welcome"
ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "assets")
JOB = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "zexos-welcome-job")

ICONS = {  # stroke icons from the design, drawn in the text colour
    "Welcome": '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
    "Keys": '<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10"/>',
    "System care": '<path d="M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
    "Drivers": '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4"/>',
    "Gaming": '<path d="M6 8h12a4 4 0 0 1 4 4v1a4 4 0 0 1-7 2.6L14 14h-4l-1 1.6A4 4 0 0 1 2 13v-1a4 4 0 0 1 4-4z"/><path d="M7 11v3M5.5 12.5h3M16 12h.01M18 13.5h.01"/>',
    "What's new": '<path d="M12 3l2.6 5.6 6.1.7-4.5 4.2 1.2 6L12 16.6 6.6 19.5l1.2-6L3.3 9.3l6.1-.7z"/>',
}
PAGES = ["Welcome", "Keys", "System care", "Drivers", "Gaming", "What's new"]

CARE = [  # job, title, one line, visible button text
    ("update", "Update", "Updates the system and your Flathub apps.", "Update"),
    ("rate-mirrors", "Faster download servers", "Tests the download servers and puts the fastest first.", "rate-mirrors"),
    ("leftovers", "Remove leftover packages",
     "Removes packages nothing needs any more. Your desktop and ZeXOS parts are never touched.", "Remove"),
    ("clean", "Clean old package files",
     "Keeps the 3 newest versions of each package, so you can still go back after a bad update.", "Clean"),
    ("unlock", 'Fix "pacman is locked"',
     "If installing software was cut off, this removes the stuck lock. Never while software is installing.", "Fix"),
]
ACCESSIBLE = {"update": "Update", "rate-mirrors": "rate-mirrors", "leftovers": "Remove leftover packages",
              "clean": "Clean old package files", "unlock": 'Fix "pacman is locked"', "gaming": "Set up for gaming"}

# The note under a job while its terminal is open, and when it is done.
RUNNING = {"update": "Updating…", "rate-mirrors": "Rating mirrors…", "leftovers": "Removing leftovers…",
           "clean": "Cleaning…", "unlock": "Fixing the lock…", "gaming": "Setting up gaming…"}
DONE = {"update": "System updated", "rate-mirrors": "Mirrors rated", "leftovers": "Leftovers removed",
        "clean": "Old package files cleaned", "unlock": "Lock removed", "gaming": "Gaming packages installed"}
FAILED = {"update": "Update failed, see the terminal", "rate-mirrors": "Mirror rating failed, see the terminal",
          "leftovers": "Removing leftovers failed, see the terminal", "clean": "Cleaning failed, see the terminal",
          "unlock": "Fixing the lock failed, see the terminal", "gaming": "Gaming setup failed, see the terminal"}
LOGDIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "zexos-welcome")


# ---------------------------------------------------------------- colours from the palette

def mix(a, b, t):
    return QColor(round(a.red() + (b.red() - a.red()) * t), round(a.green() + (b.green() - a.green()) * t),
                  round(a.blue() + (b.blue() - a.blue()) * t))


def colours(pal):
    bg = pal.color(QPalette.ColorRole.Window)
    text = pal.color(QPalette.ColorRole.WindowText)
    accent = pal.color(QPalette.ColorRole.Highlight)
    dark = bg.lightnessF() < 0.5
    edge = QColor("black") if dark else QColor("white")
    c = {
        "bg": bg, "text": text, "accent": accent,
        "accentText": pal.color(QPalette.ColorRole.HighlightedText),
        "side": mix(bg, edge, 0.18 if dark else 0.35) if dark else mix(bg, text, 0.05),
        "surface": mix(bg, text, 0.06) if dark else mix(bg, QColor("white"), 0.7),
        "hero": mix(bg, accent, 0.16),
        "muted": mix(text, bg, 0.32),
        "line": mix(bg, text, 0.14),
        "cap": mix(bg, text, 0.12) if dark else QColor("white"),
        "capLine": mix(bg, text, 0.28),
        "ok": mix(QColor("#3ddc97"), text, 0.15) if dark else QColor("#1f7a4d"),
        "okBg": mix(bg, QColor("#3ddc97"), 0.18),
        "wait": mix(QColor("#ffd166"), text, 0.15) if dark else QColor("#8a5a00"),
        "waitBg": mix(bg, QColor("#ffd166"), 0.2),
        "bad": mix(QColor("#ff6b6b"), text, 0.15) if dark else QColor("#b42318"),
        "badBg": mix(bg, QColor("#ff6b6b"), 0.18),
        "attention": mix(QColor("#ff9f43"), text, 0.15) if dark else QColor("#a8460a"),
        "attentionBg": mix(bg, QColor("#ff9f43"), 0.2),
        "knob": QColor("white") if dark else mix(bg, QColor("white"), 0.9),
        "dark": dark,
    }
    return c


def qss(c):
    h = {k: v.name() for k, v in c.items() if isinstance(v, QColor)}
    return f"""
QMainWindow, #root {{ background: {h['bg']}; color: {h['text']}; }}
QLabel {{ color: {h['text']}; background: transparent; }}
QLabel[muted="true"] {{ color: {h['muted']}; }}
QLabel[h1="true"] {{ font-family: Nunito; font-weight: 800; font-size: 26px; }}
QLabel[h2="true"] {{ font-family: Nunito; font-weight: 800; font-size: 19px; }}
QLabel[strong="true"] {{ font-weight: 600; font-size: 15px; }}
QLabel[ok="true"] {{ background: {h['okBg']}; color: {h['ok']}; border-radius: 10px; padding: 3px 10px;
                     font-size: 12px; font-weight: 600; }}
QLabel[wait="true"] {{ background: {h['waitBg']}; color: {h['wait']}; border-radius: 10px; padding: 3px 10px;
                       font-size: 12px; font-weight: 600; }}
QLabel[bad="true"] {{ background: {h['badBg']}; color: {h['bad']}; border-radius: 10px; padding: 3px 10px;
                      font-size: 12px; font-weight: 600; }}
QLabel[attention="true"] {{ background: {h['attentionBg']}; color: {h['attention']}; border-radius: 10px; padding: 3px 10px;
                            font-size: 12px; font-weight: 600; }}
QLabel[cap="true"] {{ font-family: 'JetBrains Mono'; font-size: 12px; padding: 2px 5px; border-radius: 6px;
                      background: {h['cap']}; border: 1px solid {h['capLine']}; border-bottom-width: 2px; }}
QLabel[chip="true"] {{ padding: 4px 11px; border-radius: 13px; background: {h['surface']};
                       border: 1px solid {h['line']}; font-size: 13px; }}
#side, #bottom {{ background: {h['side']}; }}
#bottom {{ border-top: 1px solid {h['line']}; }}
#brand {{ font-family: Nunito; font-weight: 800; font-size: 15px; }}
QPushButton[nav="true"] {{ text-align: left; padding: 0 12px; min-height: 44px; border: 0; border-radius: 10px;
                          background: transparent; color: {h['muted']}; font-size: 14px; font-weight: 500; }}
QPushButton[nav="true"]:checked {{ background: {h['hero']}; color: {h['text']}; border-left: 3px solid {h['accent']}; }}
QPushButton[nav="true"]:hover:!checked {{ color: {h['text']}; }}
QFrame[hero="true"] {{ background: {h['hero']}; border-radius: 16px; }}
QFrame[row="true"] {{ background: {h['surface']}; border-radius: 12px; }}
QPushButton[card="true"] {{ background: {h['surface']}; border: 1px solid {h['line']}; border-radius: 14px;
                           min-height: 96px; text-align: left; }}
QPushButton[card="true"]:hover {{ border-color: {h['accent']}; }}
QPushButton[primary="true"] {{ background: {h['accent']}; color: {h['accentText']}; border: 0; border-radius: 10px;
                              min-height: 44px; padding: 0 18px; font-size: 14px; font-weight: 600; }}
QPushButton[primary="true"][big="true"] {{ min-height: 48px; padding: 0 24px; font-size: 15px; }}
QPushButton[tryit="true"] {{ background: transparent; color: {h['text']}; border: 1px solid {h['accent']};
                            border-radius: 8px; min-height: 34px; min-width: 60px; max-width: 72px; padding: 0 8px; font-size: 13px; }}
QPushButton[tryit="true"]:disabled {{ border-color: {h['line']}; color: {h['muted']}; }}
QPushButton[ghost="true"] {{ background: transparent; color: {h['text']}; border: 1px solid {h['line']};
                            border-radius: 8px; min-height: 36px; padding: 0 14px; font-size: 13px; }}
QTextBrowser {{ background: {h['surface']}; color: {h['text']}; border: 0; border-radius: 12px; padding: 12px 16px; }}
QScrollArea, QScrollArea > QWidget > QWidget {{ background: transparent; border: 0; }}
QDialog {{ background: {h['bg']}; border: 2px solid {h['accent']}; border-radius: 16px; }}
a {{ color: {h['accent']}; }}
"""


def svg_icon(body, colour, size=18):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" '
           f'stroke="{colour.name()}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{body}</svg>')
    r = QSvgRenderer(svg.encode())
    pm = QPixmap(size * 2, size * 2)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    r.render(p)
    p.end()
    pm.setDevicePixelRatio(2)
    return QIcon(pm)


def svg_pixmap(path, height):
    r = QSvgRenderer(path)
    if not r.isValid():
        return QPixmap()
    size = r.defaultSize()
    w = max(1, round(size.width() * height / max(1, size.height())))
    pm = QPixmap(w * 2, height * 2)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    r.render(p)
    p.end()
    pm.setDevicePixelRatio(2)
    return pm


def label(text, **props):
    lab = QLabel(text)
    lab.setWordWrap(props.pop("wrap", True))
    for k, v in props.items():
        lab.setProperty(k, v)
    lab.setTextInteractionFlags(Qt.TextInteractionFlag.LinksAccessibleByMouse)
    return lab


def status_label():
    """The green note under a job ("Nothing to remove"): one line, as tall as its text."""
    st = label("", ok=True, wrap=False)
    st.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)
    st.hide()
    return st


# The note's colour says where things stand:
#   wait (yellow)  still going, e.g. "Updating…"
#   ok   (green)   done, or nothing was needed ("Nothing to clean")
#   bad  (red)     failed, cancelled, or could not start
#   attention (orange)  a check found something nobody has tried to fix yet
#                  (Drivers: "Missing: newest NVIDIA driver")
TONES = ("ok", "wait", "bad", "attention")


def show_status(st, text, tone="ok"):
    if not st.property(tone):
        for t in TONES:
            st.setProperty(t, t == tone)
        st.style().unpolish(st)
        st.style().polish(st)
    st.setText(text)
    st.setToolTip(text)
    st.adjustSize()
    st.show()


# Narrow window (for example tiled next to a terminal in Hyprland): below
# these widths of the page area, the pages rearrange instead of being cut off.
KEYS_ONE_COLUMN = 700   # Keys: one column of rows instead of two (two need about 705)
STACK_HERO = 640        # Gaming: the big button goes under its text


class CloseButton(QAbstractButton):
    """The close button: a rounded rectangle like the About button, with
    the cross drawn as two lines from the exact middle, so it reads as a
    button and not as the letter x. Turns red on hover."""

    W, H, ARM = 58, 34, 6.0

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedSize(self.W, self.H)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setAttribute(Qt.WidgetAttribute.WA_Hover)

    def paintEvent(self, ev):
        c = getattr(self.window(), "c", None) or colours(QApplication.palette())
        hover = self.underMouse()
        down = self.isDown()
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        box = QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5)
        p.setPen(QPen(c["bad"] if hover or down else c["line"], 1))
        p.setBrush(c["bad"] if down else c["badBg"] if hover else c["surface"])
        p.drawRoundedRect(box, 8, 8)
        pen = QPen(c["accentText"] if down else c["bad"] if hover else c["text"], 2.2)
        pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        p.setPen(pen)
        cx, cy, a = box.center().x(), box.center().y(), self.ARM
        p.drawLine(QPointF(cx - a, cy - a), QPointF(cx + a, cy + a))
        p.drawLine(QPointF(cx + a, cy - a), QPointF(cx - a, cy + a))
        if self.hasFocus():
            p.setPen(QPen(c["accent"], 1.5))
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.drawRoundedRect(box.adjusted(1.5, 1.5, -1.5, -1.5), 7, 7)
        p.end()

    def enterEvent(self, ev):
        self.update()
        super().enterEvent(ev)

    def leaveEvent(self, ev):
        self.update()
        super().leaveEvent(ev)


class Toggle(QAbstractButton):
    """A phone-style on/off switch with its words on the left; the whole
    thing is one button, so clicking the words flips it too."""

    W, H = 44, 24

    def __init__(self, text, parent=None):
        super().__init__(parent)
        self.setText(text)
        self.setCheckable(True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self._pos = 0.0
        self._anim = QPropertyAnimation(self, b"knob", self)
        self._anim.setDuration(160)
        self._anim.setEasingCurve(QEasingCurve.Type.InOutCubic)
        self.toggled.connect(self._slide)

    def get_knob(self):
        return self._pos

    def set_knob(self, v):
        self._pos = v
        self.update()

    knob = Property(float, get_knob, set_knob)

    def setChecked(self, on):
        super().setChecked(on)
        self._anim.stop()
        self.set_knob(1.0 if on else 0.0)

    def _slide(self, on):
        self._anim.stop()
        self._anim.setStartValue(self._pos)
        self._anim.setEndValue(1.0 if on else 0.0)
        self._anim.start()

    def sizeHint(self):
        return QSize(self.fontMetrics().horizontalAdvance(self.text()) + 12 + self.W, max(self.H, self.fontMetrics().height()) + 4)

    def paintEvent(self, ev):
        c = getattr(self.window(), "c", None) or colours(QApplication.palette())
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        tw = self.width() - self.W - 12
        p.setPen(c["text"])
        p.drawText(QRectF(0, 0, tw, self.height()), int(Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignRight), self.text())
        track = QRectF(self.width() - self.W, (self.height() - self.H) / 2, self.W, self.H)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(mix(c["capLine"], c["accent"], self._pos))
        p.drawRoundedRect(track, self.H / 2, self.H / 2)
        d = self.H - 6
        x = track.left() + 3 + (self.W - 6 - d) * self._pos
        p.setBrush(c["knob"])
        p.drawEllipse(QRectF(x, track.top() + 3, d, d))
        if self.hasFocus():
            p.setPen(c["accent"])
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.drawRoundedRect(track.adjusted(-2, -2, 2, 2), self.H / 2 + 2, self.H / 2 + 2)
        p.end()


def open_link(url):
    """Open a web link in the user's browser through zexos-browser (the
    same as Mod+B). Qt's own way asks the system for the web-link app, and
    with no default browser set that is DankMaterialShell's "open with"
    picker, which asks every time. zexos-browser skips that picker."""
    url = url.toString() if isinstance(url, QUrl) else str(url)
    browser = os.path.expanduser("~/.local/bin/zexos-browser")
    if not (os.access(browser, os.X_OK) and QProcess.startDetached(browser, [url])[0]):
        QDesktopServices.openUrl(QUrl(url))


def run_detached(cmd):
    QProcess.startDetached("sh", ["-c", cmd])


# ---------------------------------------------------------------- the window

class Welcome(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(TITLE)
        self.resize(1080, 700)
        self.setMinimumSize(820, 560)
        self.comp = core.compositor()
        self.status = {}
        self.running = {}
        self.care_buttons = []
        root = QWidget(objectName="root")
        self.setCentralWidget(root)
        outer = QVBoxLayout(root)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)
        body = QHBoxLayout()
        body.setSpacing(0)
        outer.addLayout(body, 1)

        side = QWidget(objectName="side")
        side.setFixedWidth(224)
        sl = QVBoxLayout(side)
        sl.setContentsMargins(14, 22, 14, 22)
        sl.setSpacing(6)
        brand = QHBoxLayout()
        brand.setContentsMargins(8, 0, 8, 18)
        brand.setSpacing(10)
        self.mark = QLabel()
        self.mark.setPixmap(svg_pixmap(os.path.join(ASSETS, "zexos-mark.svg"), 30))
        brand.addWidget(self.mark)
        self.brand = QLabel(objectName="brand")
        self.brand.setAccessibleName("ZeXOS - Welcome")
        brand.addWidget(self.brand, 1)
        sl.addLayout(brand)
        self.stack = QStackedWidget()
        self.stack.setContentsMargins(0, 50, 0, 0)   # room for the close button, above any scroll bar
        self.nav = {}
        for i, name in enumerate(PAGES):
            b = QPushButton("  " + name)
            b.setAccessibleName(name)
            b.setProperty("nav", True)
            b.setCheckable(True)
            b.setIconSize(QSize(18, 18))
            b.clicked.connect(lambda _=False, i=i: self.show_page(i))
            sl.addWidget(b)
            self.nav[name] = b
        sl.addStretch(1)
        body.addWidget(side)

        self.pages = [self.page_welcome(), self.page_keys(), self.page_care(), self.page_drivers(), self.page_gaming(),
                      self.page_news()]
        for p in self.pages:
            sc = QScrollArea()
            sc.setWidgetResizable(True)
            sc.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            sc.setFrameShape(QFrame.Shape.NoFrame)
            wrap = QWidget()
            wl = QVBoxLayout(wrap)
            wl.setContentsMargins(30, 6, 30, 28)
            wl.addWidget(p)
            wl.addStretch(1)
            sc.setWidget(wrap)
            self.stack.addWidget(sc)
        body.addWidget(self.stack, 1)

        bottom = QWidget(objectName="bottom")
        bl = QHBoxLayout(bottom)
        bl.setContentsMargins(18, 10, 18, 10)
        about = QPushButton("About")
        about.setAccessibleName("About")
        about.setProperty("ghost", True)
        about.clicked.connect(self.show_about)
        bl.addWidget(about)
        bl.addStretch(1)
        self.startup = Toggle("Show at startup")
        self.startup.setAccessibleName("Show at startup")
        self.startup.setChecked(core.startup_on())
        self.startup.toggled.connect(core.set_startup)
        bl.addWidget(self.startup)
        outer.addWidget(bottom)

        # A close button in the top right corner, for anyone who doesn't
        # know Mod+Q yet. It floats over the pages, so it is placed by hand
        # (see resizeEvent).
        self.close_btn = CloseButton(root)
        self.close_btn.setAccessibleName("Close")
        self.close_btn.setToolTip("Close  (Mod+Q closes any window)")
        self.close_btn.clicked.connect(self.close)
        self.close_btn.raise_()

        self.restyle()
        self.show_page(0)

    # ------------------------------------------------------------ style, live

    def changeEvent(self, ev):
        if ev.type() in (QEvent.Type.PaletteChange, QEvent.Type.ApplicationPaletteChange, QEvent.Type.StyleChange):
            QTimer.singleShot(0, self.restyle)
        super().changeEvent(ev)

    def resizeEvent(self, ev):
        super().resizeEvent(ev)
        self.adapt()
        self.close_btn.move(self.centralWidget().width() - self.close_btn.width() - 8, 8)  # tucked in the corner, like a window control
        self.close_btn.raise_()

    def adapt(self):
        """Rearrange the pages for the width the page area has now."""
        width = self.stack.width() - 60   # the pages' side margins
        cols = 1 if width < KEYS_ONE_COLUMN else 2
        if cols != self.key_cols:
            self.key_cols = cols
            for n, row in enumerate(self.key_rows):
                self.key_grid.removeWidget(row)
            for n, row in enumerate(self.key_rows):
                self.key_grid.addWidget(row, n // cols, n % cols)
        stacked = width < STACK_HERO
        want = QBoxLayout.Direction.TopToBottom if stacked else QBoxLayout.Direction.LeftToRight
        if self.hero_row.direction() != want:
            self.hero_row.setDirection(want)
            self.hero_row.setAlignment(self.hero_btn, Qt.AlignmentFlag.AlignLeft if stacked
                                       else Qt.AlignmentFlag.AlignVCenter)

    def even_care_buttons(self):
        """System care buttons all as wide as the widest one, text centred,
        so the column of buttons lines up at any window size."""
        for b in self.care_buttons:
            b.setMinimumWidth(0)
        w = max(b.sizeHint().width() for b in self.care_buttons)
        h = max(b.sizeHint().height() for b in self.care_buttons)
        for b in self.care_buttons:
            # height too: a page that hasn't been shown yet isn't laid out, so its buttons would
            # otherwise have no real size until it is (Drivers' button must match System care's)
            b.setFixedSize(w, h)

    def restyle(self):
        pal = QApplication.palette()
        key = (pal.color(QPalette.ColorRole.Window).name(), pal.color(QPalette.ColorRole.Highlight).name())
        if getattr(self, "_style_key", None) == key:
            return
        self._style_key = key
        c = colours(pal)
        self.c = c
        QApplication.instance().setStyleSheet(qss(c))
        QTimer.singleShot(0, self.even_care_buttons)   # once the new style has its sizes
        for name, b in self.nav.items():
            b.setIcon(svg_icon(ICONS[name], c["text"]))
        self.close_btn.update()
        self.brand.setText(f'ZeXOS <span style="font-weight:600; color:{c["muted"].name()}">- Welcome</span>')
        logo = "zexos-logo-dark.svg" if c["dark"] else "zexos-logo-light.svg"
        self.hero_logo.setPixmap(svg_pixmap(os.path.join(ASSETS, logo), 64))

    def show_page(self, i):
        self.stack.setCurrentIndex(i)
        for j, name in enumerate(PAGES):
            self.nav[name].setChecked(i == j)
        if PAGES[i] == "What's new":
            self.fill_news()
        if PAGES[i] == "Drivers" and not self.drivers_filled:
            self.fill_drivers()

    def heading(self, lay, title, sub):
        lay.addWidget(label(title, h1=True))
        if sub:
            lay.addWidget(label(sub, muted=True))
        lay.addSpacing(6)

    # ------------------------------------------------------------ pages

    def page_welcome(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(16)
        hero = QFrame()
        hero.setProperty("hero", True)
        hl = QHBoxLayout(hero)
        hl.setContentsMargins(28, 26, 28, 26)
        self.hero_logo = QLabel()
        self.hero_logo.setAccessibleName("ZeXOS")
        hl.addWidget(self.hero_logo)
        hl.addStretch(1)
        lay.addWidget(hero)
        lay.addWidget(label("Welcome to ZeXOS", h1=True))
        lay.addWidget(label("Your desktop is ready. Here are a few things to help you get started.", muted=True))
        grid = QGridLayout()
        grid.setSpacing(14)
        cards = [("Learn the basic keys", "12 keys to find your way around, with a Try it button for each.", lambda: self.show_page(PAGES.index("Keys"))),
                 ("Keep your system healthy", "Update, faster download servers and tidying up.", lambda: self.show_page(PAGES.index("System care"))),
                 ("Set up for gaming", "Steam, Lutris, Wine and the tools games need, in one click.", lambda: self.show_page(PAGES.index("Gaming"))),
                 ("Check your drivers", "See the drivers picked for your graphics, Wi-Fi and network, and fix any that are missing.", lambda: self.show_page(PAGES.index("Drivers"))),
                 ("Get apps", "Open the app store to find and install more apps.", self.get_apps)]
        # Four equal columns, each card two wide: a card left alone on the
        # last row sits in the middle two, the same width as the others.
        for c in range(4):
            grid.setColumnStretch(c, 1)
        for n, (t, d, fn) in enumerate(cards):
            b = QPushButton()
            b.setProperty("card", True)
            b.setAccessibleName(t)
            b.setAccessibleDescription(d)
            bl = QVBoxLayout(b)
            bl.setContentsMargins(20, 16, 20, 16)
            bl.setSpacing(6)
            bl.addWidget(label(t, strong=True))
            bl.addWidget(label(d, muted=True))
            b.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
            b.clicked.connect(fn)
            alone = n == len(cards) - 1 and n % 2 == 0
            grid.addWidget(b, n // 2, 1 if alone else (n % 2) * 2, 1, 2)
        lay.addLayout(grid)
        return w

    def page_keys(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        self.heading(lay, "Basic keys", "Mod is the Windows key. Press Mod+F1 any time to see every other key.")
        grid = QGridLayout()
        grid.setHorizontalSpacing(14)
        grid.setVerticalSpacing(8)
        self.key_grid, self.key_rows, self.key_cols = grid, [], 2
        two_shells = len(core.shells_installed()) >= 2
        for n, (caps, name, note, cmd, needs) in enumerate(KEYS):
            missing = needs == "two-shells" and not two_shells
            row = QFrame()
            row.setProperty("row", True)
            rl = QHBoxLayout(row)
            rl.setContentsMargins(12, 8, 12, 8)
            rl.setSpacing(12)
            capw = QWidget()
            capw.setFixedWidth(128)
            cl = QHBoxLayout(capw)
            cl.setContentsMargins(0, 0, 0, 0)
            cl.setSpacing(4)
            for cap in caps:
                k = label(cap, cap=True, wrap=False)
                k.setSizePolicy(QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Fixed)
                cl.addWidget(k, 0, Qt.AlignmentFlag.AlignVCenter)
            cl.addStretch(1)
            rl.addWidget(capw, 0, Qt.AlignmentFlag.AlignVCenter)
            tl = QVBoxLayout()
            tl.setSpacing(2)
            tl.addWidget(label(name))
            if missing:
                tl.addWidget(label(NOT_INSTALLED, muted=True))
            elif note:
                tl.addWidget(label(note, muted=True))
            rl.addLayout(tl, 1)
            if cmd is not None:
                b = QPushButton("Try it")
                b.setAccessibleName("Try it")
                b.setAccessibleDescription(name)
                b.setProperty("tryit", True)
                b.setEnabled(not missing)
                c = command(cmd, self.comp)
                b.clicked.connect(lambda _=False, c=c: run_detached(c))
                rl.addWidget(b, 0, Qt.AlignmentFlag.AlignVCenter)
            if missing:
                row.setEnabled(False)
            grid.addWidget(row, n // 2, n % 2)
            self.key_rows.append(row)
        lay.addLayout(grid)
        return w

    def page_care(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(10)
        self.heading(lay, "System care", "Each job opens a terminal so you can see what happens, asks for your password, "
                                         "and shows what it will change before it does anything.")
        for job, title, desc, btn in CARE:
            row = QFrame()
            row.setProperty("row", True)
            rl = QHBoxLayout(row)
            rl.setContentsMargins(18, 14, 18, 14)
            rl.setSpacing(16)
            tl = QVBoxLayout()
            tl.setSpacing(3)
            tl.addWidget(label(title, strong=True))
            tl.addWidget(label(desc, muted=True))
            st = status_label()
            tl.addWidget(st, 0, Qt.AlignmentFlag.AlignLeft)
            self.status[job] = st
            rl.addLayout(tl, 1)
            b = QPushButton(btn)
            self.care_buttons.append(b)
            b.setAccessibleName(ACCESSIBLE[job])
            b.setProperty("primary", True)
            b.clicked.connect(lambda _=False, j=job: self.run_job(j))
            rl.addWidget(b)
            lay.addWidget(row)
        return w

    def page_drivers(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(10)
        self.heading(lay, "Drivers", "The drivers ZeXOS picked for this computer's graphics, Wi-Fi and network chips. "
                                     "Checking needs no password; it is asked for only when something has to change.")
        self.chip_rows = QVBoxLayout()
        self.chip_rows.setSpacing(10)
        lay.addLayout(self.chip_rows)
        row = QFrame()
        row.setProperty("row", True)
        rl = QHBoxLayout(row)
        rl.setContentsMargins(18, 14, 18, 14)
        rl.setSpacing(16)
        tl = QVBoxLayout()
        tl.setSpacing(3)
        tl.addWidget(label("Check drivers", strong=True))
        tl.addWidget(label("Scans the chips again and compares them with what is installed. If something is missing, "
                           "it shows exactly what it will install, then asks for your password.", muted=True))
        self.drivers_status = status_label()
        tl.addWidget(self.drivers_status, 0, Qt.AlignmentFlag.AlignLeft)
        self.drivers_detail = label("", muted=True)
        self.drivers_detail.hide()
        tl.addWidget(self.drivers_detail)
        rl.addLayout(tl, 1)
        b = QPushButton("Check again")
        b.setAccessibleName("Check again")
        b.setProperty("primary", True)
        b.clicked.connect(self.drivers_action)
        self.care_buttons.append(b)      # same size as the System care buttons
        rl.addWidget(b)
        self.drivers_button = b
        lay.addWidget(row)
        lay.addWidget(label("The same from a terminal: zexos-drivers status, zexos-drivers check.", muted=True))
        self.drivers_filled = False
        self.drivers_fix = []            # sets "Fix" will install
        self.drivers_proc = None
        return w

    def page_gaming(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(14)
        self.heading(lay, "Gaming", "One click installs what you need to start playing: Steam, Lutris, Wine, and the tools "
                                    "that make games run smoothly. Everything comes from Arch's and ZeXOS's own software sources.")
        hero = QFrame()
        hero.setProperty("hero", True)
        hl = QVBoxLayout(hero)
        hl.setContentsMargins(24, 22, 24, 22)
        top = QBoxLayout(QBoxLayout.Direction.LeftToRight)
        top.setSpacing(16)
        self.hero_row = top
        tl = QVBoxLayout()
        tl.addWidget(label("Set up for gaming", h2=True))
        tl.addWidget(label("Only what's missing is installed. You see the list in the terminal first.", muted=True))
        top.addLayout(tl, 1)
        b = QPushButton("Set up for gaming")
        b.setAccessibleName(ACCESSIBLE["gaming"])
        b.setProperty("primary", True)
        b.setProperty("big", True)
        b.clicked.connect(lambda: self.run_job("gaming"))
        top.addWidget(b, 0, Qt.AlignmentFlag.AlignVCenter)
        self.hero_btn = b
        hl.addLayout(top)
        st = status_label()
        hl.addWidget(st, 0, Qt.AlignmentFlag.AlignLeft)
        self.status["gaming"] = st
        lay.addWidget(hero)
        lay.addWidget(label("What it installs", strong=True))
        chips = QWidget()
        cl = FlowLayout(chips, 6)
        for name in core.GAMING_APPS:
            cl.addWidget(label(name, chip=True, wrap=False))
        lay.addWidget(chips)
        lay.addWidget(label("Installed as ZeXOS's zexos-gaming-applications package, with zexos-gaming-meta underneath "
                            "(Wine and the libraries and fonts Windows games need). Graphics drivers come from the ZeXOS "
                            "installer.", muted=True))
        return w

    def page_news(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(12)
        self.news_title = label("", h1=True)
        lay.addWidget(self.news_title)
        self.news_text = QTextBrowser()
        self.news_text.setOpenLinks(False)
        self.news_text.anchorClicked.connect(open_link)
        self.news_text.setMinimumHeight(330)
        self.news_text.setAccessibleName("What's new")
        lay.addWidget(self.news_text)
        self.news_foot = label("From the change notes on this computer. No internet needed.", muted=True)
        self.news_foot.linkActivated.connect(open_link)
        self.news_foot.setTextInteractionFlags(Qt.TextInteractionFlag.TextBrowserInteraction)
        lay.addWidget(self.news_foot)
        return w

    def fill_news(self):
        r = core.newest_release()
        if not r:
            self.news_title.setText("What's new")
            self.news_text.setMarkdown("What's new isn't available on this computer.\n\n"
                                       f"Read it online: [{core.CHANGELOG_URL}]({core.CHANGELOG_URL})")
            self.news_foot.setText(f'<a href="{core.CHANGELOG_URL}">{core.CHANGELOG_URL}</a>')
            return
        v, date, notes = r
        self.news_title.setText(f"What's new in ZeXOS {v}" + (f"   ·   {date}" if date else ""))
        self.news_text.setMarkdown(notes)
        self.news_foot.setText("From the change notes on this computer. No internet needed.")

    # ------------------------------------------------------------ drivers

    def drivers_note(self, text, tone, detail=""):
        show_status(self.drivers_status, text, tone)
        self.drivers_detail.setText(detail)
        self.drivers_detail.setVisible(bool(detail))

    def fill_drivers(self):
        """The chips and their drivers (zexos-drivers status, no password)."""
        self.drivers_filled = True
        while self.chip_rows.count():
            it = self.chip_rows.takeAt(0)
            if it.widget():
                it.widget().deleteLater()
        try:
            r = subprocess.run(["zexos-drivers", "status", "--json"], capture_output=True, text=True, timeout=20)
            st = json.loads(r.stdout)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            self.drivers_note("Couldn't read the drivers", "bad", "The zexos-drivers command is missing or failed.")
            return
        p, have = st["plan"], set(st.get("installed", []))
        descs = p.get("descs", {})
        rows = []
        for c in p["chips"]:
            s = next((a for a in p["alternatives"].get(c["set"], []) if a in have), c["set"])
            rows.append((c["name"], descs.get(s, s), s in have))
        chip_sets = [c["set"] for c in p["chips"]]
        for s in p["sets"]:
            if s not in chip_sets and s in have:
                rows.append(("Also", descs.get(s, s), True))
        if not rows:
            rows.append(("No extra drivers are needed on this computer.", "", True))
        for name, desc, on in rows:
            row = QFrame()
            row.setProperty("row", True)
            rl = QVBoxLayout(row)
            rl.setContentsMargins(18, 12, 18, 12)
            rl.setSpacing(2)
            rl.addWidget(label(name, strong=True))
            if desc:
                rl.addWidget(label(desc + ("" if on else "  ·  not installed"), muted=True))
            self.chip_rows.addWidget(row)
        fails = [f for f in st.get("failures", []) if not st.get("ack", True)]
        builds = st.get("legacy_builds", {})
        if builds.get("linux") == "failed":   # a kernel update the legacy driver couldn't be rebuilt for
            backup = ' Pick "ZeXOS (backup kernel)" in the start menu for full graphics.' \
                if builds.get("linux-lts") == "ok" else ""
            self.drivers_note("Driver rebuild failed", "bad", "The legacy NVIDIA driver couldn't be rebuilt after "
                              "the last kernel update, so this kernel uses basic graphics." + backup)
        elif fails:   # red until it is fixed or Check again shows where things stand now
            f = fails[-1]
            d = descs.get(f["set"], f["set"])
            self.drivers_note("Driver install failed", "bad", f"The {d} couldn't be installed ({f['reason']}). "
                              "Press Check again to see what is needed now.")

    def drivers_action(self):
        if self.drivers_proc is not None:
            return
        if self.drivers_fix:
            self.drivers_install(self.drivers_fix)
        else:
            self.drivers_check()

    def drivers_run(self, prog, args, done):
        proc = QProcess(self)
        self.drivers_proc = proc
        proc.finished.connect(lambda code, _st: self.drivers_done(proc, code, done))
        proc.errorOccurred.connect(lambda err: err == QProcess.ProcessError.FailedToStart and self.drivers_done(proc, -1, done))
        proc.start(prog, args)

    def drivers_done(self, proc, code, done):
        if self.drivers_proc is not proc:
            return
        self.drivers_proc = None
        out = bytes(proc.readAllStandardOutput()).decode(errors="replace")
        err = bytes(proc.readAllStandardError()).decode(errors="replace")
        done(code, out, err)

    def drivers_check(self):
        self.drivers_note("Checking…", "wait")
        self.drivers_run("zexos-drivers", ["check", "--json"], self.drivers_checked)

    def drivers_checked(self, code, out, err):
        try:
            ch = json.loads(out)
        except ValueError:
            self.drivers_note("Couldn't check the drivers", "bad", (err.strip().splitlines() or [""])[-1])
            return
        self.fill_drivers()
        missing = ch.get("install", [])
        if not missing:
            self.drivers_fix = []
            self.drivers_button.setText("Check again")
            self.drivers_note("All drivers OK", "ok")
            return
        names = [ch.get("descs", {}).get(s, s) for s in missing]
        one = len(names) == 1 and len(names[0]) <= 24
        self.drivers_note(f"Missing: {names[0]}" if one else f"{len(names)} drivers missing" if len(names) > 1
                          else "1 driver missing", "attention",
                          f"Fix installs: {', '.join(names)}  ({', '.join(ch.get('packages', []))}). "
                          "Your password is asked next.")
        self.drivers_fix = missing
        self.drivers_button.setText("Fix")
        self.drivers_button.setAccessibleName("Fix drivers")

    def drivers_install(self, sets):
        self.drivers_note("Installing drivers…", "wait", self.drivers_detail.text())
        self.drivers_run("pkexec", ["/usr/bin/zexos-drivers-helper", "install", *sets], self.drivers_installed)

    def drivers_installed(self, code, out, err):
        self.drivers_fix = []
        self.drivers_button.setText("Check again")
        self.drivers_button.setAccessibleName("Check again")
        if code == 0:
            self.fill_drivers()
            self.drivers_note("Drivers installed, restart to use them", "ok")
        elif code in (126, 127):   # pkexec: password window closed / not allowed
            self.drivers_note("Cancelled, nothing changed", "bad")
        else:
            self.fill_drivers()
            self.drivers_note("Driver install failed", "bad", (err.strip().splitlines() or ["See zexos-drivers status."])[-1])

    # ------------------------------------------------------------ actions

    def get_apps(self):
        cmd = core.app_store_cmd()
        if cmd:
            QProcess.startDetached(cmd[0], cmd[1:])

    def run_job(self, job):
        st = self.status[job]
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            kind, msg, _ = core.plan(job)
        finally:
            QApplication.restoreOverrideCursor()
        if kind in ("nothing", "stop"):
            show_status(st, msg, "ok" if kind == "nothing" else "bad")
            return
        term = shutil.which("kitty")
        if not term:
            show_status(st, "No terminal (kitty) found", "bad")
            return
        if job in self.running:
            return
        rc_file = os.path.join(LOGDIR, f"{job}.rc")
        try:
            os.remove(rc_file)
        except OSError:
            pass
        ok, pid = QProcess.startDetached(term, ["--class", "zexos-welcome-job", "--title", f"{TITLE}: {ACCESSIBLE[job]}",
                                                "-e", "bash", JOB, job])
        if not ok:
            show_status(st, "The terminal did not open", "bad")
            return
        show_status(st, RUNNING[job], "wait")
        # Detached on purpose: closing this window never stops an update.
        # The job writes how it ended to <job>.rc; watch for it.
        timer = QTimer(self)
        self.running[job] = timer
        timer.timeout.connect(lambda j=job, f=rc_file, p=pid: self.check_job(j, f, p))
        timer.start(700)

    def check_job(self, job, rc_file, pid):
        st = self.status[job]
        try:
            rc = open(rc_file).read().strip()
        except OSError:
            rc = None
        if rc is None:
            try:
                os.kill(pid, 0)
                return          # still running
            except OSError:
                pass            # terminal closed before the job finished
        self.running.pop(job).stop()
        if rc == "0":
            show_status(st, DONE[job])
        elif rc == "2":
            show_status(st, "Cancelled, nothing changed", "bad")
        elif rc == "3":
            show_status(st, "Could not start, see the terminal", "bad")
        elif rc is None:
            show_status(st, "Stopped before it finished", "bad")
        else:
            show_status(st, FAILED[job], "bad")

    def show_about(self):
        d = QDialog(self)
        d.setWindowTitle("About ZeXOS")
        d.setAccessibleName("About ZeXOS")
        lay = QVBoxLayout(d)
        lay.setContentsMargins(28, 26, 28, 22)
        lay.setSpacing(10)
        m = QLabel()
        m.setPixmap(svg_pixmap(os.path.join(ASSETS, "zexos-mark.svg"), 56))
        lay.addWidget(m, 0, Qt.AlignmentFlag.AlignHCenter)
        v = core.version()
        t = label(f"ZeXOS {v}" if v else "ZeXOS", h2=True)
        t.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        lay.addWidget(t)
        s = label("A ready-to-use desktop built on Arch Linux.", muted=True)
        s.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        lay.addWidget(s)
        link = label('<a href="https://github.com/zefuros1991/ZeXOS">github.com/zefuros1991/ZeXOS</a>')
        link.linkActivated.connect(open_link)
        link.setTextInteractionFlags(Qt.TextInteractionFlag.TextBrowserInteraction)
        link.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        lay.addWidget(link)
        close = QPushButton("Close")
        close.setAccessibleName("Close")
        close.setProperty("primary", True)
        close.clicked.connect(d.accept)
        lay.addWidget(close, 0, Qt.AlignmentFlag.AlignHCenter)
        d.setFixedWidth(380)
        d.exec()


class FlowLayout(QLayout):
    """Chips side by side that wrap onto the next line when the page is
    narrow (Qt's flow layout example, trimmed)."""

    def __init__(self, parent, spacing):
        super().__init__(parent)
        self.setContentsMargins(0, 0, 0, 0)
        self.gap = spacing
        self.items = []

    def addItem(self, item):
        self.items.append(item)

    def count(self):
        return len(self.items)

    def itemAt(self, i):
        return self.items[i] if 0 <= i < len(self.items) else None

    def takeAt(self, i):
        return self.items.pop(i) if 0 <= i < len(self.items) else None

    def expandingDirections(self):
        return Qt.Orientation(0)

    def hasHeightForWidth(self):
        return True

    def heightForWidth(self, width):
        return self.place(QRect(0, 0, width, 0), move=False)

    def setGeometry(self, rect):
        super().setGeometry(rect)
        self.place(rect, move=True)

    def sizeHint(self):
        return self.minimumSize()

    def minimumSize(self):
        size = QSize()
        for item in self.items:
            size = size.expandedTo(item.minimumSize())
        return size

    def place(self, rect, move):
        x, y, line = rect.x(), rect.y(), 0
        for item in self.items:
            hint = item.sizeHint()
            if x + hint.width() > rect.right() + 1 and line > 0:
                x, y, line = rect.x(), y + line + self.gap, 0
            if move:
                item.setGeometry(QRect(QPoint(x, y), hint))
            x += hint.width() + self.gap
            line = max(line, hint.height())
        return y + line - rect.y()


def run():
    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("zexos-welcome")
    app.setDesktopFileName("zexos-welcome")
    win = Welcome()
    win.show()
    return app.exec()
