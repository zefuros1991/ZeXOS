"""The welcome app's brain: every check and list, no window code.

The window (ui.py) and the terminal command (zexos-welcome <job>) both use
this module, so whatever a button does can also be run and tested from a
terminal. Nothing here needs root; root work happens only in
zexos-welcome-job, inside a visible terminal, through pkexec.
"""
import glob
import os
import re
import shutil
import subprocess

HOME = os.path.expanduser("~")
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "zexos")
NO_WELCOME = os.path.join(CONF, "no-welcome")
CHANGELOG = os.path.join(HOME, ".dotfiles", "CHANGELOG.md")
CHANGELOG_URL = "https://github.com/zefuros1991/ZeXOS/blob/main/CHANGELOG.md"
SHARE = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local", "share")), "zexos-welcome")
PROTECTED_LIST = os.path.join(SHARE, "protected.list")  # written by scripts/packages.sh (git-ignored)
RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "zexos-welcome")
LOCK = "/var/lib/pacman/db.lck"
CACHE = "/var/cache/pacman/pkg"
NVIDIA_GUIDE = "https://wiki.archlinux.org/title/NVIDIA"

# REQ-26: the Arch version of CachyOS's gaming bundle (cachyos-gaming-meta +
# cachyos-gaming-applications), Arch repos only: no Heroic, no Flathub, no AUR.
GAMING = [
    "steam", "lutris", "wine", "winetricks", "protontricks", "umu-launcher",
    "gamemode", "lib32-gamemode", "mangohud", "lib32-mangohud", "gamescope", "goverlay",
    "vulkan-tools", "alsa-plugins", "lib32-alsa-plugins", "giflib", "glfw",
    "gst-plugins-base-libs", "lib32-gtk3", "libjpeg-turbo", "lib32-libjpeg-turbo",
    "libva", "lib32-libva", "libxslt", "mpg123", "openal", "ocl-icd", "lib32-ocl-icd",
    "ttf-liberation", "wqy-zenhei",
]
# The apps shown as chips on the Gaming page (the rest are support libraries and fonts).
GAMING_APPS = ["Steam", "Lutris", "Wine", "winetricks", "protontricks", "umu-launcher",
               "GameMode", "MangoHud", "gamescope", "GOverlay", "vulkan-tools"]

GAMING_PACKAGE = "zexos-gaming-applications"   # pulls in zexos-gaming-meta (packaging/)
GAMING_PACKAGES = ["zexos-gaming-applications", "zexos-gaming-meta"]
DRIVER_GUIDE = "https://wiki.archlinux.org/title/Vulkan#Installation"

# The jobs (contracts/cli.md). Admin jobs open a terminal when they have something to do.
ADMIN_JOBS = ["update", "rate-mirrors", "leftovers", "clean", "unlock", "gaming"]
JOBS = ADMIN_JOBS + ["get-apps", "whats-new", "about", "startup"]


def run(argv, **kw):
    try:
        return subprocess.run(argv, capture_output=True, text=True, **kw)
    except FileNotFoundError:
        return subprocess.CompletedProcess(argv, 127, "", f"{argv[0]}: not found")


# ---------------------------------------------------------------- startup

def startup_on():
    return not os.path.exists(NO_WELCOME)


def set_startup(on):
    if on:
        if os.path.exists(NO_WELCOME):
            os.remove(NO_WELCOME)
    else:
        os.makedirs(CONF, exist_ok=True)
        open(NO_WELCOME, "w").close()


def autostart_allowed():
    """Open at login only if "Show at startup" is on, and only once per login
    (zshell start also runs when the desktop shell is switched)."""
    if not startup_on():
        return False
    os.makedirs(RUNTIME, exist_ok=True)
    marker = os.path.join(RUNTIME, "autostarted")
    if os.path.exists(marker):
        return False
    open(marker, "w").close()
    return True


# ---------------------------------------------------------------- change notes

_SECTION = re.compile(r"^## \[(\d+\.\d+\.\d+)\]([^\n]*)\n(.*?)(?=^## \[|\Z)", re.M | re.S)


def newest_release():
    """(version, date, notes markdown) of the newest numbered section, or None."""
    try:
        with open(CHANGELOG, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return None
    m = _SECTION.search(text)
    if not m:
        return None
    date = m.group(2).strip(" -")
    return m.group(1), date, m.group(3).strip()


def version():
    r = newest_release()
    return r[0] if r else None


# ---------------------------------------------------------------- what is installed

def installed(pkg):
    return run(["pacman", "-Q", pkg]).returncode == 0


def installed_set(pkgs):
    r = run(["pacman", "-Q", *pkgs])
    return {line.split()[0] for line in r.stdout.splitlines() if line.strip()}


def shells_installed():
    have = installed_set(["noctalia-zexos", "noctalia", "dms-shell", "dms-shell-bin", "dms-shell-git"])
    out = []
    if have & {"noctalia-zexos", "noctalia"}:
        out.append("noctalia")
    if have & {"dms-shell", "dms-shell-bin", "dms-shell-git"}:
        out.append("dms")
    return out


def compositor():
    if os.environ.get("NIRI_SOCKET"):
        return "niri"
    if os.environ.get("MANGO_INSTANCE_SIGNATURE"):
        return "mango"
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return "hyprland"
    d = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()
    for c in ("niri", "mango", "hyprland"):
        if c in d:
            return c
    return "niri"


# ---------------------------------------------------------------- software job state

def software_job_running():
    """True when pacman (or a tool holding its lock) is really working."""
    return run(["pgrep", "-x", "pacman"]).returncode == 0


def lock_state():
    """'none' | 'stale' | 'busy'"""
    if not os.path.exists(LOCK):
        return "none"
    return "busy" if software_job_running() else "stale"


def protected():
    names = set(GAMING) | set(GAMING_PACKAGES)
    try:
        with open(PROTECTED_LIST) as fh:
            names |= set(fh.read().split())
    except OSError:
        pass
    r = run(["pacman", "-Slq", "zexos"])
    if r.returncode == 0:
        names |= set(r.stdout.split())
    return names


def leftovers():
    r = run(["pacman", "-Qdtq"])
    prot = protected()
    return [p for p in r.stdout.split() if p not in prot]


def _paccache(args, cache=None):
    """paccache dry run: the package files it would delete (it prints bare file names)."""
    cache = cache or CACHE
    r = run(["paccache", "-c", cache, *args])
    files = [os.path.join(cache, l.strip()) for l in r.stdout.splitlines()
             if re.search(r"\.pkg\.tar(\.\w+)?$", l.strip()) and not l.startswith("==>")]
    return files


def old_package_files(cache=None):
    """Files Clean would delete: all but the 3 newest versions of each package,
    plus every version of packages no longer installed (paccache -dk3, -duk0)."""
    a = _paccache(["-dvk3"], cache)
    b = _paccache(["-dvuk0"], cache)
    files = sorted(set(a) | set(b))
    size = 0
    for f in files:
        try:
            size += os.path.getsize(f)
        except OSError:
            pass
    return files, size


def human_size(n):
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024


# ---------------------------------------------------------------- gaming

def has_32bit_driver():
    r = run(["pacman", "-T", "lib32-vulkan-driver"])
    return r.returncode == 0 and not r.stdout.strip()


def in_repos(pkg):
    return run(["pacman", "-Si", pkg]).returncode == 0


def gaming_plan():
    """Set up for gaming installs one ZeXOS package. Graphics drivers are the
    ZeXOS installer's job: if they're missing, stop and say so (REQ-28)."""
    if installed(GAMING_PACKAGE):
        return ("nothing", "Gaming is already set up", [])
    if not has_32bit_driver():
        return ("stop", "Graphics drivers aren't set up yet. See the guide: " + DRIVER_GUIDE, [])
    if not in_repos(GAMING_PACKAGE):
        return ("stop", "The ZeXOS gaming package isn't available yet; update the system first.", [])
    return ("todo", "Install ZeXOS's gaming package (pacman lists everything it brings)", [GAMING_PACKAGE])


# ---------------------------------------------------------------- plans for every admin job

def plan(job):
    """What a job would do right now, without doing it. Same answers in the window and the terminal."""
    if job in ("leftovers", "clean", "gaming", "update", "rate-mirrors", "unlock") and job != "unlock" \
            and lock_state() == "busy":
        return ("stop", "Another software job is running right now. Wait for it to finish, then try again.", [])
    if job == "leftovers":
        items = leftovers()
        return ("todo", f"{len(items)} leftover packages", items) if items else ("nothing", "Nothing to remove", [])
    if job == "clean":
        files, size = old_package_files()
        if not files:
            return ("nothing", "Nothing to clean", [])
        return ("todo", f"{len(files)} files, {human_size(size)}", files)
    if job == "unlock":
        st = lock_state()
        if st == "none":
            return ("nothing", "No lock found", [])
        if st == "busy":
            return ("stop", "Software is being installed right now, so the lock is in use and is kept.", [])
        return ("todo", "A stuck lock was left behind", [LOCK])
    if job == "gaming":
        return gaming_plan()
    if job == "update":
        return ("todo", "Update the system, then your Flathub apps", [])
    if job == "rate-mirrors":
        return ("todo", "Find the fastest download servers", [])
    raise ValueError(job)


def format_check(p):
    kind, msg, items = p
    lines = [f"{kind}: {msg}"] + [f"item: {i}" for i in items]
    return "\n".join(lines)


def app_store_cmd():
    s = os.path.join(HOME, ".local", "bin", "zexos-app-store")
    if os.access(s, os.X_OK):
        return [s]
    for c in ("shelly", "plasma-discover"):
        if shutil.which(c):
            return [c]
    return None
