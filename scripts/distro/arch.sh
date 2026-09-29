# Steps for Arch Linux and distros that use Arch's own repos (EndeavourOS,
# ...). Sourced by packages.sh after install_pacman and install_local
# exist; not meant to be run on its own.
#
# These systems don't have the CachyOS-only package ZeXOS uses, so it
# gets a stand-in. If you added the CachyOS repos yourself, the real
# package is used instead (the step asks pacman first).

# App store (Mod+M). Shelly is CachyOS-only; KDE Discover (installed by
#    bootstrap.sh) does the same job, and zexos-app-store picks whichever
#    one is there.
if zexos_in_repos shelly; then
    install_pacman "Package manager app (Shelly)" shelly
else
    echo -e "${CYAN}ℹ Shelly is CachyOS-only -- Mod+M opens KDE Discover instead${RESET}"
fi
