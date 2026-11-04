# Installing ZeXOS

ZeXOS is a Linux distro based on Arch. The normal way to get it is the installer ISO: write it to a USB stick and install ZeXOS on a PC. If you'd rather keep the Arch-based system you already have, you can add the ZeXOS desktop to it with one command instead.

| You want | Do this |
|---|---|
| ZeXOS as your system (new PC, or a clean start) | [Install from the ISO](#install-zexos-from-the-iso) |
| To keep your current Arch, CachyOS or EndeavourOS | [Add the desktop to your system](#keep-your-system-add-the-zexos-desktop) |

## Install ZeXOS from the ISO

1. Download the installer ISO from the [Releases page](https://github.com/zefuros1991/ZeXOS/releases/latest).
2. Write it to a USB stick and boot the PC from it. You get a graphical and a text installer.
3. Follow the installer. It installs Arch and ZeXOS together.

Your system shows up as ZeXOS, and it's still Arch underneath, so Arch packages and guides work. Everything about the ISO, step by step: [Download, boot, install](../iso/README.md).

## Keep your system: add the ZeXOS desktop

Already running Arch, CachyOS or EndeavourOS and don't want a clean install? The install script adds the ZeXOS desktop on top of that system. Your files, apps and old desktop stay. It takes about 2½ minutes on a fresh Arch.

### Before you start

**Tested and working**

- CachyOS
- Arch Linux
- EndeavourOS

Other Arch-based distros that use Arch's own repos are likely to work too, but haven't been tried yet. The desktop you picked during that distro's install (KDE, GNOME, niri or none) doesn't matter. ZeXOS adds what's missing, and your old desktop stays in the login screen's session list.

**Not supported**

- **Manjaro**: it has its own, delayed repos.
- **Artix**: it doesn't use systemd.

On those two the installer stops early and says why.

**You need**

- [ ] A normal user account that can use `sudo`. Don't run it as root.
- [ ] A network connection.

`git` is added for you if it's missing. Everything else, including `stow`, comes with the install.

### Run the script

1. Open a terminal as your normal user.
2. Paste this and press Enter:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/zefuros1991/ZeXOS/main/install.sh -o /tmp/zexos-install.sh; bash /tmp/zexos-install.sh; rm -f /tmp/zexos-install.sh
   ```

   It downloads the installer, runs it, then deletes it. It works the same in fish, bash and zsh.

3. Type your `sudo` password when asked. The gradient ZeXOS logo animates while the installer waits for it.

   <p align="center"><img src="screenshots/install.gif" alt="The ZeXOS installer starting in a terminal: the gradient ZeXOS logo animates while it waits for the sudo password" width="640"></p>

4. Choose **1. Ready-made** when asked how to get ZeXOS's own packages. It is the default and the fast one. [Not sure? Compare the two.](install-options.md#ready-made-or-build-it-yourself)
5. Wait for it to finish. At the end you get a short result for each part, ✔ or ✖.
6. Log out. On the login screen, pick **niri**, **Hyprland** or **Mango** from the session menu next to the password box.

**Already cloned the repo to `~/.dotfiles`?**

```bash
cd ~/.dotfiles
./install.sh
```

## Something went wrong?

On the ISO, the log is `/var/log/zexos-install.log` on the new system. With the script, every step keeps a log in `~/.dotfiles`. Look there first. See [Troubleshooting](troubleshooting.md) for fixes by symptom.

## Next

- [Install options](install-options.md): for the script, install only some compositors or shells, or build the packages yourself
- [Main keybinds](keybinds.md): the keys you use every day

---

[Back to the README](../README.md) · [All docs](README.md)
