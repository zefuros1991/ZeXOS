# Steps for Arch Linux and distros that use Arch's own repos (EndeavourOS,
# ...). Sourced by packages.sh after install_pacman and install_local
# exist; not meant to be run on its own.
#
# These systems don't have the two CachyOS-only packages ZeXOS uses, so
# each one gets a stand-in. If you added the CachyOS repos yourself, the
# real package is used instead (every step asks pacman first).

# 1. Zen browser (Mod+B). Not in Arch's repos, so it is repacked from
#    Zen's official release. pacman won't update it by itself: running
#    install.sh again does, once packaging/zen-browser-zexos moves on.
if zexos_in_repos zen-browser-bin; then
    install_pacman "Web browser (Zen)" zen-browser-bin
else
    install_local "Web browser (Zen)" zen-browser-zexos
fi

# 2. App store (Mod+M). Shelly is CachyOS-only; KDE Discover (installed by
#    bootstrap.sh) does the same job, and zexos-app-store picks whichever
#    one is there.
if zexos_in_repos shelly; then
    install_pacman "Package manager app (Shelly)" shelly
else
    echo -e "${CYAN}ℹ Shelly is CachyOS-only -- Mod+M opens KDE Discover instead${RESET}"
fi
