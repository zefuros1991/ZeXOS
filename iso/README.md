# ZeXOS installer ISO

Put ZeXOS on an empty PC from a USB stick. The stick holds two installers, a window one and a text one. Both install Arch and ZeXOS together.

## 1. Download it

Get the newest ISO from the [Releases page](https://github.com/zefuros1991/ZeXOS/releases/latest) and write it to a USB stick with any USB-writing tool. The file is called `ZeXOS-v2.0.0-x86_64.iso`, with the version number of the release.

To check that the download is complete and really from ZeXOS, also download `SHA256SUMS` and `SHA256SUMS.asc` into the same folder and run:

```bash
sha256sum -c --ignore-missing SHA256SUMS
gpg --verify SHA256SUMS.asc SHA256SUMS
```

The first line should say `OK`. The second should say "Good signature" from "ZeXOS Package Signing" (key `D429340F700A6F86C921E8A801F22C6FAC9CF960`). If gpg says it doesn't know the key, that is normal on a new computer; compare the key ID.

## 2. Before you boot

- **Internet.** Both installers download Arch and ZeXOS while they install, so the PC needs a connection (cable or Wi-Fi).
- **UEFI.** The installed system starts with systemd-boot, which needs a UEFI PC. GRUB and Limine are planned.
- **Backups.** If you let the installer erase the disk, everything on it is gone.

## 3. Pick an installer

Boot from the stick. The start menu offers three entries:

| Start menu entry | What you get |
|---|---|
| **ZeXOS (window installer)** | A small desktop with a normal installer window and a slideshow while it installs. The default, and the easiest. |
| **ZeXOS (text installer)** | The ZeXOS logo and one plain question per screen, then a summary to check, then a progress screen. |
| **ZeXOS (safe graphics)** | The window installer with basic graphics. Use it if the first entry shows a black screen. |

## 4. What it asks

Both installers ask for the same things:

- Language, time zone and keyboard
- Which disk to use
- Your user name and password
- Which compositors and shells to install: any mix of niri, Hyprland and Mango, and Noctalia and DankMaterialShell. [Not sure which? Compare them.](../docs/compositors-and-shells.md) If you pick a single shell, the shell switcher is left out.

The window installer also lets you pick graphics drivers, and lets you split the disk yourself instead of erasing it.

## 5. After it finishes

Restart, remove the stick, and log in. Pick your compositor from the session menu next to the password box. Your system shows up as ZeXOS, and it's still Arch underneath, so Arch packages and guides work.

Next: [Main keybinds](../docs/keybinds.md).

## If something goes wrong

The log of the ZeXOS part is `/var/log/zexos-install.log` on the new system. See [Troubleshooting](../docs/troubleshooting.md), or [open an issue](https://github.com/zefuros1991/ZeXOS/issues/new) with that log.

---

[Back to the README](../README.md) · [Installing ZeXOS](../docs/install.md)
