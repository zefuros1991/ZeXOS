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

If stow reports "no conflicts" on a dry run, that package is already correctly deployed and there's nothing to do. If it reports a conflict, that means a real (non-symlink) file already exists at the target — `stow.sh` itself handles this automatically by backing the real file up to `backup/stow-<timestamp>/` before linking, but doing it by hand with the commands above works too, just remember to move the conflicting real file out of the way first.

Two packages (`theme` and `systemd`) can never fully "fold" into a single clean symlink because something outside stow's control (Noctalia rewriting live CSS, and pre-existing systemd user units) keeps a real directory in place at the target. That's expected — not a bug — see the comments in those two package folders if you're curious.

## A warning about the shell

**`finaltouches.sh` sets the login shell to `zsh`.** In practice, `fish` is the shell actually used day to day on this machine (zsh is only launched inside Kitty via its own `shell` directive, and interactively at login fish is what you'll land in already — see `stow/fish/` for that config). If you re-run `finaltouches.sh` on a fresh machine, it will flip your login shell to zsh. That's intentional for a truly clean bootstrap, but if you want fish to be the login shell instead, either skip this script or edit it to `chsh -s fish` before running it.

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
