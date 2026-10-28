#!/usr/bin/env bash
# Run by iso/build.sh with the profile folder as $1, after the common files
# were copied in.
#
# The stick's start menu (UEFI systemd-boot, BIOS syslinux, GRUB and its
# loopback menu), in this order:
#   ZeXOS (window installer)  the normal entry: the live desktop + Calamares
#   ZeXOS (text installer)    zexos.installer=text: the text installer on tty1
#   ZeXOS (safe graphics)     basic graphics (nomodeset) with NVIDIA's driver
#                             kept off, for cards that show a black screen
# The normal entry is renamed by build.sh; this adds the other two after it.
set -euo pipefail
profile="${1:?}"
text="zexos.installer=text"
safe="nomodeset module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm"

# id | title | one-line help (syslinux) | extra kernel options | systemd-boot sort key
entries=(
    "zexostext|ZeXOS (text installer)|The installer in text screens, without the live desktop.|$text|012"
    "zexossafe|ZeXOS (safe graphics)|Basic graphics, for a graphics card that shows a black screen.|$safe|015"
)

# UEFI (systemd-boot): an entry file each, sorted right after the normal one.
for e in "${entries[@]}"; do
    IFS='|' read -r id title _ opts key <<<"$e"
    cat > "$profile/efiboot/loader/entries/01-$id.conf" <<EOF
title    $title
sort-key $key
linux    /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
initrd   /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
options  archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% %KERNEL_PARAMS% $opts
EOF
done

# BIOS (syslinux): LABELs after the first one.
python3 - "$profile/syslinux/archiso_sys-linux.cfg" "${entries[@]}" <<'EOF'
import sys
path, entries = sys.argv[1], [e.split("|") for e in sys.argv[2:]]
s = open(path).read()
block = ""
for id, title, help, opts, _ in entries:
    if id in s:
        continue
    block += f"""LABEL {id}
TEXT HELP
{help}
ENDTEXT
MENU LABEL {title}
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% %KERNEL_PARAMS% {opts}

"""
marker = "\n# Accessibility boot option"
if block:
    s = s.replace(marker, "\n" + block + marker.lstrip("\n"), 1) if marker in s else s + "\n" + block
open(path, "w").write(s)
EOF

# GRUB (and the menu used when the ISO file is booted from another GRUB):
# menuentries after the first one.
for cfg in "$profile/grub/grub.cfg" "$profile/grub/loopback.cfg"; do
    [ -f "$cfg" ] || continue
    python3 - "$cfg" "${entries[@]}" <<'EOF'
import re, sys
path, entries = sys.argv[1], [e.split("|") for e in sys.argv[2:]]
s = open(path).read()
m = re.search(r'^menuentry "[^"]*" [^\n]*--id \'archlinux\' \{\n(.*?)^\}\n', s, re.M | re.S)
if not m:
    sys.exit(f"{path}: normal menu entry not found")
add = ""
for id, title, _, opts, _ in entries:
    if f'"{title}"' in s:
        continue
    body = re.sub(r"^(\s*linux .*)$", lambda x: x.group(1) + " " + opts, m.group(1), count=1, flags=re.M)
    add += f"\nmenuentry \"{title}\" --class arch --class gnu-linux --class gnu --class os --id '{id}' {{\n" + body + "}\n"
s = s[:m.end()] + add + s[m.end():]
open(path, "w").write(s)
EOF
done
