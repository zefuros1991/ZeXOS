# Steps for Arch Linux and distros that use Arch's own repos (EndeavourOS,
# ...). Sourced by packages.sh after install_pacman and install_local
# exist; not meant to be run on its own.
#
# These systems don't have the CachyOS-only package ZeXOS uses, so it
# gets a stand-in. If you added the CachyOS repos yourself, the real
# package is used instead (the step asks pacman first).

# App store (Mod+M). Shelly is CachyOS-only; KDE Discover (installed by
# bootstrap.sh) does the same job, and zexos-app-store picks whichever
# one is there.
if zexos_in_repos shelly; then
    install_pacman "Package manager app (Shelly)" shelly
else
    echo -e "${CYAN}ℹ Shelly is CachyOS-only -- Mod+M opens KDE Discover instead${RESET}"
fi

# Web browser (Mod+B). ZeXOS doesn't choose a browser for you, but a bare
# Arch install has none at all, and then Mod+B has nothing to open. So
# Firefox is added only when no installed app can open web links; if you
# already have any browser (Firefox, Chromium, a Flatpak, ...), nothing
# is installed.
has_browser=0
for dir in /usr/share/applications /usr/local/share/applications \
           "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
           /var/lib/flatpak/exports/share/applications \
           "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share/applications"; do
    if grep -qs 'x-scheme-handler/https' "$dir"/*.desktop; then
        has_browser=1
        break
    fi
done
if [ "$has_browser" -eq 0 ]; then
    install_pacman "Web browser (Firefox, none was installed)" firefox
else
    echo -e "${CYAN}ℹ A web browser is already installed -- Mod+B opens your default one${RESET}"
fi
