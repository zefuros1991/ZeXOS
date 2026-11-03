# Troubleshooting

Find what you see, then try the fix under it. If none of them help, [open an issue](https://github.com/zefuros1991/ZeXOS/issues/new) and attach the log (see [Contributing](../CONTRIBUTING.md#reporting-a-problem)).

## Installing

<details>
<summary>The installer stops straight away and names a distro</summary>

ZeXOS doesn't support **Manjaro** (its repos are delayed and its own) or **Artix** (no systemd). The installer stops early on purpose. See [Installing ZeXOS](install.md#before-you-start).

</details>

<details>
<summary>The final summary shows a ✖</summary>

Open the log for that part in `~/.dotfiles` (`bootstrap.log`, `packages.log`, `stow.log` or `finaltouches.log`). The whole run is in `install.log`. If the install of the packages failed, the installer retried them one at a time, so the log names the one that caused it.

</details>

<details>
<summary>A ready-made package was built here instead</summary>

That's the fallback, not a fault. It happens when a download is missing or damaged, or doesn't match your system. See [Install options](install-options.md#ready-made-or-build-it-yourself).

</details>

## Colours and themes

<details>
<summary>Dolphin or other open apps stopped following the wallpaper after an update</summary>

ZeXOS rebuilds the piece that makes this work after every Qt update, and sometimes that rebuild fails. Check how the last one went:

```bash
journalctl -u zexos-qt6ct-rebuild
```

</details>

<details>
<summary>A GTK app (like Shelly) still has the old colours</summary>

GTK only reads its colours when an app starts. Close the app and open it again. Open KDE apps, kitty and the rest change by themselves.

</details>

<details>
<summary>Colours don't follow the wallpaper under DankMaterialShell</summary>

A small background helper does the colour parts DankMaterialShell doesn't. Check that it is running:

```bash
systemctl --user status zexos-dms-sync.path
```

</details>

<details>
<summary>The desktop is in light (or dark) mode and I want the other one</summary>

A very bright wallpaper switches to light mode on its own. To choose the mode yourself, create the file `~/.config/zexos/manual-theme-mode`.

</details>

## Wallpapers

<details>
<summary>No animated wallpaper is playing</summary>

None is switched on by default, because a looping 4K video puts a small, constant load on the machine. Press `Mod+Shift+W` and pick one. Under DankMaterialShell, which can't play videos, you get the first frame as a still. See [Wallpapers and screens](wallpapers-and-screens.md#animated-wallpapers).

</details>

## Compositors and shells

<details>
<summary>A key I know from niri does nothing in Mango or Hyprland</summary>

A few niri keys don't exist there (jump to the first or last window, for example). See the lists in [Compositors and shells](compositors-and-shells.md).

</details>

<details>
<summary>The ⇄ button or <code>Mod+Shift+D</code> is missing</summary>

With only one shell installed, the shell switcher is left out. See [Install options](install-options.md#install-only-some-compositors-or-shells).

</details>

<details>
<summary>DankMaterialShell has no USB drive button or no "Restart to UEFI"</summary>

DMS can't do those yet. Drives still mount from Dolphin.

</details>

## Terminal

<details>
<summary>I don't want the ZeXOS prompt or system info in kitty</summary>

Create one of these empty files:

- `~/.config/zexos/no-prompt` turns the prompt off
- `~/.config/zexos/no-fastfetch` turns the system info off

A prompt you set up yourself (starship, oh-my-posh, powerlevel10k, an oh-my-zsh theme, your own fish prompt) is always left alone.

</details>

---

[Back to the README](../README.md) · [All docs](README.md)
