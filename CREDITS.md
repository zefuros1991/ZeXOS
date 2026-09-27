# Credits

ZeXOS is my own setup and my own config files, plus small changes to other
people's projects. This page lists whose work is in here.

## Files in this repo that build on other people's code

| File | Based on | Author | License |
|---|---|---|---|
| `packaging/noctalia-zexos/zexos.patch` | [Noctalia](https://github.com/noctalia-dev/noctalia) | noctalia-dev | MIT |
| `packaging/roller/zexos-wheel-and-size.patch` | [roller](https://github.com/zyrophix/roller) | zyrophix | MIT |
| `stow/zsh/.config/zsh/.p10k.zsh` | made with the [Powerlevel10k](https://github.com/romkatv/powerlevel10k) setup wizard | Roman Perepelitsa (romkatv) | MIT |

The two patches were written for ZeXOS. They change the original programs,
and each patch also contains a few unchanged lines of the original code so it
knows where to apply. The PKGBUILDs download the original source from its
authors and apply the patch while building. Those programs keep their own
licenses.

## Software ZeXOS installs

The installer downloads everything else (niri, Noctalia, kitty, fuzzel, Dolphin,
Shelly, Zen Browser and the rest) from its official source: the Arch/CachyOS
repos, the AUR, or Flathub. None of their code is copied into this repo. Each
one keeps its own license and belongs to its authors.

Special thanks to [niri](https://github.com/YaLTeR/niri) by Ivan Molodetskikh
and [Noctalia](https://noctalia.dev). This desktop is built around them.
