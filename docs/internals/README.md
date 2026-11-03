# ZeXOS internals

For people who work on ZeXOS: how it is built, packaged and signed. **If you just want to use ZeXOS, you don't need any of this.** Start at [Installing ZeXOS](../install.md).

| Page | What is in it |
|---|---|
| [How the installer works](how-the-installer-works.md) | What `install.sh` and each script in `scripts/` do, and where the logs go |
| [Building the ISO](building-the-iso.md) | Build the installer ISO, how both installers work inside, the ZeXOS name, picker previews |
| [Packages and patches](packages-and-patches.md) | How ZeXOS's own packages are built and served, and the patches on top of other projects |
| [Desktop and wallpapers](desktop-and-wallpapers.md) | The shell helper, how DankMaterialShell gets its look, and the scripts that draw the wallpapers |
| [Changing the signing key](../../packaging/zexos-keyring/ROTATION.md) | Runbook for replacing the key that signs ZeXOS packages |

Before you send a fix, read [CONTRIBUTING](../../CONTRIBUTING.md).
