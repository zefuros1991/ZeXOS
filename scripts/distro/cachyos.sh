# Steps that only apply to CachyOS. Sourced by packages.sh after
# install_pacman and install_local exist; not meant to be run on its own.
#
# CachyOS's repos carry everything here ready-made, so this is just pacman.

# Shelly: a point-and-click app for installing and updating software.
# Mod+M opens it (through zexos-app-store).
install_pacman "Package manager app (Shelly)" shelly

# Zen browser: CachyOS repacks Zen's official release as zen-browser-bin,
# so pacman updates it like everything else. Mod+B opens it.
if zexos_in_repos zen-browser-bin; then
    install_pacman "Web browser (Zen)" zen-browser-bin
else
    install_local "Web browser (Zen)" zen-browser-zexos
fi
