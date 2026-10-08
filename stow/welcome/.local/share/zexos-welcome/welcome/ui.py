"""The ZeXOS - Welcome window (PySide6 / Qt Widgets).

Layout follows the approved design (specs: design/project/Main.dc.html):
sidebar with the pages, content on the right, a bottom bar with About and
"Show at startup". Every colour comes from the Qt palette, which ZeXOS
sets from the wallpaper through qt6ct; when the wallpaper changes, Qt sends
a palette change and the window restyles itself while open.
"""
import os
import shutil
import sys

from PySide6.QtCore import QEvent, QProcess, QSize, Qt, QTimer, QUrl
from PySide6.QtGui import QColor, QDesktopServices, QFont, QFontDatabase, QIcon, QPainter, QPalette, QPixmap
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtWidgets import (QApplication, QCheckBox, QDialog, QFrame, QGridLayout, QHBoxLayout, QLabel,
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
    "Gaming": '<path d="M6 8h12a4 4 0 0 1 4 4v1a4 4 0 0 1-7 2.6L14 14h-4l-1 1.6A4 4 0 0 1 2 13v-1a4 4 0 0 1 4-4z"/><path d="M7 11v3M5.5 12.5h3M16 12h.01M18 13.5h.01"/>',
    "What's new": '<path d="M12 3l2.6 5.6 6.1.7-4.5 4.2 1.2 6L12 16.6 6.6 19.5l1.2-6L3.3 9.3l6.1-.7z"/>',
}
PAGES = ["Welcome", "Keys", "System care", "Gaming", "What's new"]

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
QCheckBox {{ color: {h['text']}; spacing: 8px; }}
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

        self.pages = [self.page_welcome(), self.page_keys(), self.page_care(), self.page_gaming(), self.page_news()]
        for p in self.pages:
            sc = QScrollArea()
            sc.setWidgetResizable(True)
            sc.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            sc.setFrameShape(QFrame.Shape.NoFrame)
            wrap = QWidget()
            wl = QVBoxLayout(wrap)
            wl.setContentsMargins(30, 28, 30, 28)
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
        self.startup = QCheckBox("Show at startup")
        self.startup.setAccessibleName("Show at startup")
        self.startup.setChecked(core.startup_on())
        self.startup.toggled.connect(core.set_startup)
        bl.addWidget(self.startup)
        outer.addWidget(bottom)

        self.restyle()
        self.show_page(0)

    # ------------------------------------------------------------ style, live

    def changeEvent(self, ev):
        if ev.type() in (QEvent.Type.PaletteChange, QEvent.Type.ApplicationPaletteChange, QEvent.Type.StyleChange):
            QTimer.singleShot(0, self.restyle)
        super().changeEvent(ev)

    def restyle(self):
        pal = QApplication.palette()
        key = (pal.color(QPalette.ColorRole.Window).name(), pal.color(QPalette.ColorRole.Highlight).name())
        if getattr(self, "_style_key", None) == key:
            return
        self._style_key = key
        c = colours(pal)
        self.c = c
        QApplication.instance().setStyleSheet(qss(c))
        for name, b in self.nav.items():
            b.setIcon(svg_icon(ICONS[name], c["text"]))
        self.brand.setText(f'ZeXOS <span style="font-weight:600; color:{c["muted"].name()}">- Welcome</span>')
        logo = "zexos-logo-dark.svg" if c["dark"] else "zexos-logo-light.svg"
        self.hero_logo.setPixmap(svg_pixmap(os.path.join(ASSETS, logo), 64))

    def show_page(self, i):
        self.stack.setCurrentIndex(i)
        for j, name in enumerate(PAGES):
            self.nav[name].setChecked(i == j)
        if PAGES[i] == "What's new":
            self.fill_news()

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
        cards = [("Learn the basic keys", "12 keys to find your way around, with a Try it button for each.", lambda: self.show_page(1)),
                 ("Keep your system healthy", "Update, faster download servers and tidying up.", lambda: self.show_page(2)),
                 ("Set up for gaming", "Steam, Lutris, Wine and the tools games need, in one click.", lambda: self.show_page(3)),
                 ("Get apps", "Open the app store to find and install more apps.", self.get_apps)]
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
            grid.addWidget(b, n // 2, n % 2)
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
            st = label("", ok=True)
            st.hide()
            tl.addWidget(st, 0, Qt.AlignmentFlag.AlignLeft)
            self.status[job] = st
            rl.addLayout(tl, 1)
            b = QPushButton(btn)
            b.setAccessibleName(ACCESSIBLE[job])
            b.setProperty("primary", True)
            b.clicked.connect(lambda _=False, j=job: self.run_job(j))
            rl.addWidget(b)
            lay.addWidget(row)
        return w

    def page_gaming(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(14)
        self.heading(lay, "Gaming", "One click installs what you need to start playing: Steam, Lutris, Wine, and the tools "
                                    "that make games run smoothly. Everything comes from Arch's own software sources.")
        hero = QFrame()
        hero.setProperty("hero", True)
        hl = QVBoxLayout(hero)
        hl.setContentsMargins(24, 22, 24, 22)
        top = QHBoxLayout()
        tl = QVBoxLayout()
        tl.addWidget(label("Set up for gaming", h2=True))
        tl.addWidget(label("Only what's missing is installed. You see the list in the terminal first.", muted=True))
        top.addLayout(tl, 1)
        b = QPushButton("Set up for gaming")
        b.setAccessibleName(ACCESSIBLE["gaming"])
        b.setProperty("primary", True)
        b.setProperty("big", True)
        b.clicked.connect(lambda: self.run_job("gaming"))
        top.addWidget(b)
        hl.addLayout(top)
        st = label("", ok=True)
        st.hide()
        hl.addWidget(st, 0, Qt.AlignmentFlag.AlignLeft)
        self.status["gaming"] = st
        lay.addWidget(hero)
        lay.addWidget(label("What it installs", strong=True))
        chips = QWidget()
        cl = FlowRow(chips)
        for name in core.GAMING_APPS:
            cl.add(label(name, chip=True, wrap=False))
        lay.addWidget(chips)
        lay.addWidget(label("Plus 19 support libraries and fonts games need, and the 32-bit graphics piece for your "
                            "graphics card if it's missing.", muted=True))
        return w

    def page_news(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(12)
        self.news_title = label("", h1=True)
        lay.addWidget(self.news_title)
        self.news_text = QTextBrowser()
        self.news_text.setOpenExternalLinks(True)
        self.news_text.setMinimumHeight(330)
        self.news_text.setAccessibleName("What's new")
        lay.addWidget(self.news_text)
        self.news_foot = label("From the change notes on this computer. No internet needed.", muted=True)
        self.news_foot.setOpenExternalLinks(True)
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
            st.setText(msg)
            st.show()
            return
        term = shutil.which("kitty")
        if not term:
            st.setText("No terminal (kitty) found.")
            st.show()
            return
        QProcess.startDetached(term, ["--class", "zexos-welcome-job", "--title", f"{TITLE}: {ACCESSIBLE[job]}",
                                      "-e", "bash", JOB, job])
        st.setText("A terminal window opened for this job.")
        st.show()

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
        link.setOpenExternalLinks(True)
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


class FlowRow:
    """Chips that wrap onto the next line (a tiny flow layout)."""

    def __init__(self, parent):
        self.parent = parent
        self.items = []
        self.lay = QGridLayout(parent)
        self.lay.setContentsMargins(0, 0, 0, 0)
        self.lay.setSpacing(6)

    def add(self, w):
        n = len(self.items)
        self.items.append(w)
        self.lay.addWidget(w, n // 6, n % 6, Qt.AlignmentFlag.AlignLeft)


def run():
    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("zexos-welcome")
    app.setDesktopFileName("zexos-welcome")
    win = Welcome()
    win.show()
    return app.exec()
