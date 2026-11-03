# Contributing to ZeXOS

Bug reports, ideas and fixes are welcome.

## Reporting a problem

[Open an issue](https://github.com/zefuros1991/ZeXOS/issues/new). It helps to say:

- which distro you installed on, and whether you used the install script or the ISO
- which compositor (niri, Hyprland, Mango) and which shell (Noctalia, DankMaterialShell) you were using
- what you did, what you expected and what happened instead
- the log that matches the step that failed, from `~/.dotfiles` (`install.log`, `bootstrap.log`, `packages.log`, `stow.log` or `finaltouches.log`)

For a security problem, do not open a public issue. See [SECURITY.md](SECURITY.md).

## Suggesting a change

Open an issue first and describe what you would like to see. That saves you the work if the idea does not fit. ZeXOS is a one-person project, so the maintainer decides what gets merged.

## Sending a fix

1. Fork the repo and make your change on the `beta` branch. New work is tested there first.
2. If you edit Python, check it compiles (`python -m py_compile <file>`) before you push.
3. A desktop feature has to work on all three compositors (niri, Hyprland, Mango) and in both shells (Noctalia, DankMaterialShell).
4. Describe the change in plain language in the commit message and the pull request.
5. Add a line to `CHANGELOG.md` under "Unreleased".

Your contribution is covered by the project's [MIT license](LICENSE).

[Back to the README](README.md)
