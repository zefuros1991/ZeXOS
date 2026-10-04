#!/usr/bin/env bash
# Run by iso/build.sh with the profile folder as $1, after the GUI files
# were copied in. Fills in what is generated rather than kept in git.
set -euo pipefail
profile="${1:?}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
air="$profile/airootfs"
brand="$air/etc/calamares/branding/zexos"

# zexos-calamares is not in any online repo yet: build it from
# iso/gui/calamares-pkg (makepkg), put it in a local repo (repo-add) and
# point ZEXOS_CALAMARES_REPO at that folder.
local_repo="${ZEXOS_CALAMARES_REPO:-}"
if [ -z "$local_repo" ] || [ ! -f "$local_repo/zexos-iso.db" ]; then
    echo "Set ZEXOS_CALAMARES_REPO to a folder with zexos-iso.db (see iso/README.md)." >&2
    exit 1
fi
sed -i "s|@LOCALREPO@|$local_repo|" "$profile/pacman.conf"

# The installed system gets plain Arch: same pacman.conf minus the
# live-only repos.
mkdir -p "$air/etc/zexos"
sed '/^# ZEXOS-LIVE-ONLY/,$d' "$profile/pacman.conf" > "$air/etc/zexos/pacman-arch.conf"

# Wallpaper for the live desktop, and backdrops for the install slideshow.
mkdir -p "$air/usr/share/zexos" "$brand/slides" "$brand/previews"
small() { magick "$1" -resize 1920x1080 -quality 85 "$2"; }
small "$repo/wallpapers/zexos-aurora.jpg" "$air/usr/share/zexos/wallpaper.jpg"
i=1
for w in aurora topo-energy dots-forest bars-ocean mark-ember aurora-ocean; do
    small "$repo/wallpapers/zexos-$w.jpg" "$brand/slides/$i.jpg"
    i=$((i + 1))
done

# Logo and icon.
rsvg-convert -w 256 -h 256 "$repo/docs/logo/zexos-mark.svg" -o "$brand/logo.png"
rsvg-convert -w 64 -h 64 "$repo/docs/logo/zexos-mark.svg" -o "$brand/icon.png"
rsvg-convert -w 640 "$repo/docs/logo/zexos-logo-dark.svg" -o "$brand/welcome.png"

# Picker previews: recorded clips live in iso/gui/previews/<id>.webp. Until
# one is recorded, a still placeholder stands in for it.
for id in niri hyprland mango noctalia dms; do
    clip="$repo/iso/gui/previews/$id.webp"
    if [ -f "$clip" ]; then
        cp "$clip" "$brand/previews/$id.webp"
    else
        magick "$repo/wallpapers/zexos-mark.jpg" -resize 960x540^ -gravity center -extent 960x540 \
            -fill '#0f0f14b0' -draw 'rectangle 0,380 960,540' \
            -fill '#e6e6ef' -font DejaVu-Sans-Bold -pointsize 42 -gravity south -annotate +0+80 "$id" \
            -fill '#9a9ab0' -font DejaVu-Sans -pointsize 22 -annotate +0+40 "preview coming soon" \
            "$brand/previews/$id.webp"
    fi
done

# Live desktop: the installed ZeXOS niri + Noctalia setup, copied from the
# stow packages so the live session has the same look and keys. Only niri and
# Noctalia; other compositors, shells and apps come with the install.
home="$air/root"
mkdir -p "$home/.config/niri" "$home/.config/noctalia" "$home/.config/systemd/user" \
    "$home/.local/bin" "$home/.local/share" "$home/Pictures/Wallpapers"
cp -r "$repo/stow/niri/.config/niri/." "$home/.config/niri/"
echo 'include "./live.kdl"' >> "$home/.config/niri/config.kdl"   # live.kdl comes from iso/gui/airootfs
cp -r "$repo/stow/noctalia/.config/noctalia/." "$home/.config/noctalia/"
cp -r "$repo/stow/noctalia/.config/systemd/user/." "$repo/stow/desktop/.config/systemd/user/." "$home/.config/systemd/user/"
cp -r "$repo/stow/noctalia/.local/share/." "$home/.local/share/"
cp "$repo/stow/noctalia/.local/bin/"* "$repo/stow/desktop/.local/bin/"* "$home/.local/bin/"
# Not stow/desktop/.config/qt6ct: the live qt6ct.conf styles the installer.
for w in aurora topo-energy dots-forest bars-ocean mark-ember aurora-ocean; do
    small "$repo/wallpapers/zexos-$w.jpg" "$home/Pictures/Wallpapers/zexos-$w.jpg"
done

# Trim the bar for the live session: no update counter or USB widget, and
# only the keybind cheatsheet plugin. Fail loudly if a line moved.
toml="$home/.config/noctalia/noctalia.toml"
live_edit() {
    grep -q "$1" "$toml" || { echo "customize.sh: '$1' not found in noctalia.toml" >&2; exit 1; }
    sed -i "s|$1|$2|" "$toml"
}
live_edit 'members = \["sysmon", "arch_updates", "usb"\]' 'members = ["sysmon"]'
live_edit 'enabled = \["yuuto/arch-updater", "kenn/keybind-cheatsheet", "aristides/udiskie", "noctalia/mpvpaper"\]' 'enabled = ["kenn/keybind-cheatsheet"]'
live_edit 'pinned = \["kitty", "org.kde.dolphin"\]' 'pinned = ["zexos-installer", "kitty"]'

# Networking: NetworkManager instead of Arch's iwd + systemd-networkd, so the
# bar's network menu works and Wi-Fi joined here carries over to the install.
wants="$air/etc/systemd/system"
rm -f "$wants/multi-user.target.wants/iwd.service" \
    "$wants/multi-user.target.wants/systemd-networkd.service" \
    "$wants/network-online.target.wants/systemd-networkd-wait-online.service" \
    "$wants/dbus-org.freedesktop.network1.service" \
    "$wants/sockets.target.wants/systemd-networkd.socket"
mkdir -p "$wants/multi-user.target.wants" "$wants/network-online.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$wants/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service "$wants/network-online.target.wants/NetworkManager-wait-online.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service "$wants/dbus-org.freedesktop.nm-dispatcher.service"
