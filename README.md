# ZeXOS

ZeXOS is my personal setup script and dotfiles collection for this CachyOS (Arch-based) machine, running the niri window manager. The goal is simple: if this disk ever dies, or I set up a new machine, I can point it at this repo and get back to a working, familiar desktop without having to remember every package name and config file by hand.

It has two jobs:
1. **Bootstrap and install** everything this machine needs (system packages, AUR packages, Flatpak apps).
2. **Deploy config files** ("dotfiles") into the right places using [GNU Stow](https://www.gnu.org/software/stow/), so every config file actually lives inside this git repo and is just symlinked into `$HOME`.

This is a living setup that changes as I do. It is not meant to be a generic "clone and use" dotfiles repo for someone else's machine — a lot of it (package choices, GPU tweaks, hardware-specific paths) is tuned for this specific laptop.

## How install works (4 stages)

Running `install.sh` walks through four stages, in order, each handled by its own script in `scripts/`:

1. **Bootstrap** (`scripts/bootstrap.sh`) — updates the system, installs the small set of core tools needed for everything else (`git`, `curl`, `stow`, `base-devel`, `flatpak`, `discover`), installs the `yay` AUR helper if it's missing, adds the Flathub Flatpak repo, and makes sure this repo is cloned into `~/.dotfiles`.
2. **Packages** (`scripts/packages.sh`) — installs the full application list: gaming stack, virtualization tools, development tools, social apps, media codecs and players, system utilities, the Zen browser, SDDM + the Pixie login screen theme, and a handful of Flatpak apps. Skips anything already installed.
3. **Stow** (`scripts/stow.sh`) — deploys every config package under `stow/` into `$HOME` as symlinks. Safe to re-run any time; see "Re-running stow" below.
4. **Final touches** (`scripts/finaltouches.sh`) — small post-install tweaks. Currently this is just one thing: setting `zsh` as the login shell.

Each script writes its own log file at the repo root (`bootstrap.log`, `packages.log`, `stow.log`, `finaltouches.log`) — these are gitignored, so they stay local to the machine.

### Prerequisites

- A CachyOS (or Arch-based) system with `bash` and network access.
- A user account that can `sudo` (the scripts ask for your password once up front and keep it alive with a background keepalive loop while they run).
- That's it for a from-scratch run — `bootstrap.sh` installs everything else needed (including `git` and `stow` themselves).

### Running it

From a fresh machine:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zefuros1991/ZeXOS/main/install.sh)
```

Or, if the repo is already cloned to `~/.dotfiles`:

```bash
cd ~/.dotfiles
./install.sh
```

## Re-running stow for a single package

`stow.sh` normally loops over every folder in `stow/`, but you don't need the whole install flow just to redeploy one package after editing it. Stow itself can be called directly:

```bash
cd ~/.dotfiles
stow -d stow -t "$HOME" <package-name>       # deploy/re-link one package
stow -D -d stow -t "$HOME" <package-name>     # remove that package's symlinks
```

Add `-n` to either command to do a dry run first and see what it *would* do without touching anything:

```bash
stow -n -d stow -t "$HOME" <package-name>
```

A plain dry run (`-n`) only tells you whether there's a *conflict* — it exits cleanly either way, whether the package is already fully linked or just about to be linked for the first time with no conflicts, so its wording doesn't distinguish those two cases. Add `-v` as well (`stow -v -n ...`) if you want to actually see what would change: a `LINK: ...` line means that file is about to be newly linked, and no `LINK:`/`UNLINK:` lines at all means the package is already exactly right. Either way, if stow reports a conflict, that means a real (non-symlink) file already exists at the target — `stow.sh` itself handles this automatically by backing the real file up to `backup/stow-<timestamp>/` before linking, but doing it by hand with the commands above works too, just remember to move the conflicting real file out of the way first.

Two packages (`theme` and `systemd`) can never fully "fold" into a single clean symlink because something outside stow's control (Noctalia rewriting live CSS, and pre-existing systemd user units) keeps a real directory in place at the target. That's expected — not a bug — see the comments in those two package folders if you're curious.

## A warning about the shell

**`finaltouches.sh` sets the login shell to `zsh`.** In practice, `fish` is the shell actually used day to day on this machine (zsh is only launched inside Kitty via its own `shell` directive, and interactively at login fish is what you'll land in already — see `stow/fish/` for that config). If you re-run `finaltouches.sh` on a fresh machine, it will flip your login shell to zsh. That's intentional for a truly clean bootstrap, but if you want fish to be the login shell instead, either skip this script or edit it to `chsh -s fish` before running it.

## Troubleshooting

### The login screen (SDDM) hangs forever / never shows the desktop

If you ever end up staring at a black screen or a stuck SDDM login screen after entering your password, and it happens with a **plain shell** login rather than fish specifically, the classic cause on Arch/CachyOS is a broken `~/.profile`.

Here's the plain-language version of why: when SDDM starts your graphical session, it runs a little startup script (`/usr/share/sddm/scripts/wayland-session`) that begins with `#!/bin/sh`. On CachyOS, `/bin/sh` is actually `bash` running in a stricter compatibility mode. That script's job is to read your `~/.profile` (a very old, universal shell config file) before launching niri. If `~/.profile` tries to load a file that doesn't exist — for example a leftover line like `. "$HOME/.local/bin/env"` from some tool that was uninstalled later — bash-in-that-mode treats a missing file as a **fatal error** and kills the whole startup script right there. Niri never gets launched. SDDM just sits there, because from its point of view the session script is still "running" (it's actually dead, but nothing told SDDM that).

**Why this repo never deploys a `~/.profile`:** rather than trying to keep an old-style profile file perfectly error-free forever, ZeXOS relies entirely on `~/.config/environment.d/*.conf` (see the `system` package) for environment variables instead. `environment.d` is the modern, systemd-native way to set login-session variables, and it can't have this particular failure mode — there's no `.` (source) command to break. If you ever add a `~/.profile` by hand on this machine (or a future one built from this repo), keep it either empty or absolutely certain every line it sources actually exists, since this is exactly the kind of failure that's silent until the very next login.

### Git push asks for a username and password every time

GitHub no longer accepts a plain account password over HTTPS — the "password" it wants is a **Personal Access Token (PAT)**, a long random string you generate once on github.com (Settings → Developer settings → Personal access tokens) and then paste in place of your password.

The `git` stow package already configures `credential.helper = /usr/lib/git-core/git-credential-libsecret`, which ships as part of the official `git` package on Arch/CachyOS (nothing extra to install). This tells git to save that token in your desktop's secure keyring (GNOME Keyring, via the `gnome-keyring-daemon` that's normally already running) after the very first successful login, so you only ever have to type it in once per machine.

What to expect on a **brand-new machine**, the very first time you push:
1. `git push` will ask for your GitHub username, then for a "password" — paste your PAT there (it won't echo to the screen, that's normal).
2. If it works, the keyring saves it, and every push after that is silent — no prompt at all.
3. If your desktop has no keyring/secrets service running (unlikely on a normal desktop CachyOS install, but possible on a very minimal setup), the helper can't save anything and it'll ask every time. If that happens, either make sure `gnome-keyring-daemon` (or your DE's equivalent secrets service) is running, or use `gh auth login` (the GitHub CLI) instead, which handles its own token storage and reconfigures git's credential helper for you.

If push ever fails outright with an authentication error instead of prompting, don't keep retrying — GitHub temporarily blocks repeated failed auth attempts. Generate a fresh PAT and try once more.

## Package table

Every folder under `stow/` is one Stow "package" — a slice of `$HOME` that lives in this repo instead. Run `stow -d stow -t "$HOME" <name>` to deploy any one of them on its own.

| Package | Manages | Notes |
|---|---|---|
| `bash` | `.bashrc`, `.bash_profile`, `.bash_logout` | Present for completeness; not the daily shell |
| `btop` | `~/.config/btop` | Resource monitor config |
| `desktop` | `~/.config/gtkrc`, `mimeapps.list`, `xsettingsd` | Default apps + GTK settings |
| `dev` | `~/.config/go`, `~/.config/uv` | Dev tool state; `go/telemetry` is Go's own runtime spool, not hand-edited |
| `fish` | `~/.config/fish/{config.fish, conf.d/xdg.fish, functions/steam.fish}` | The actual interactive login shell config. `fish_variables` is deliberately excluded — fish rewrites that file itself on every prompt/theme change |
| `fuzzel` | `~/.config/fuzzel` | App launcher |
| `git` | `~/.config/git/config` | Uses `git-credential-libsecret`, no plaintext credentials |
| `htop` | `~/.config/htop/htoprc` | |
| `hypr` | `~/.config/hypr` | Leftover from before switching to niri; Hyprland itself is not installed on this machine |
| `input` | `kcminputrc`, `kxkbrc`, `libinput-gestures.conf` | Read by individual Qt/KDE apps under niri (no full Plasma session) |
| `kitty` | `~/.config/kitty` | Terminal config; this is where zsh gets launched from via the `shell` directive |
| `mangohud` | `~/.config/MangoHud` | In-game performance overlay |
| `millennium` | `~/.config/millennium` | Steam client theming |
| `neofetch` | `~/.config/neofetch` | |
| `niri` | `~/.config/niri` | The window manager in actual use, including monitor + input rules |
| `noctalia` | `~/.config/noctalia` | Shell/panel/theming daemon: GTK theme, wallpaper, system bar |
| `spicetify` | `~/.config/spicetify` | Spotify theming (includes a large third-party Marketplace bundle) |
| `system` | `~/.config/autostart`, `~/.config/environment.d` | Autostart entries + one leg of the XDG env var setup |
| `systemd` | `~/.config/systemd/user` | User service units (kanshi, rustdesk, niri-monitor-toggle). Hardlinked rather than symlinked due to a pre-existing real directory |
| `theme` | `gtk-3.0`, `gtk-4.0`, `Kvantum`, `qt5ct`, `qt6ct` | GTK/Qt theming; the gtk-3.0/gtk-4.0 parts get rewritten live by Noctalia, so stow will always show a conflict-then-reconcile cycle here |
| `vesktop` | `~/.config/vesktop` | Discord client; only hand-authored bits tracked (settings, quickCss, themes, window state) — cookies/cache/session data live outside the repo |
| `vscode` | `~/.config/Code/User` | VS Code settings; Settings Sync cache files are excluded |
| `vscodium` | `~/.config/VSCodium/User` | Only `settings.json` and `chatLanguageModels.json` tracked — everything else (cache, cookies, extension state) lives outside the repo at the normal `~/.config/VSCodium` location |
| `zsh` | `~/.zshrc`, `~/.config/zsh/.p10k.zsh` | The real, actually-loaded zsh config (there is no `ZDOTDIR` set anywhere — plain `~/.zshrc` is what zsh reads) |

Two apps intentionally have **no** stow package: **Obsidian** and the **Zen browser**. Both are pure Electron/browser profile data (cookies, history, IndexedDB, vault paths tied to this specific machine) with nothing hand-authored worth version-controlling — their config lives untracked at the normal `~/.config/obsidian` and `~/.config/zen` locations instead.
