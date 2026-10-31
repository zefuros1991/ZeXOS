#!/usr/bin/env bash
# Keeps ZeXOS's package-signing key safe: the master key (the root of trust)
# goes offline, and a spare "signing subkey" does the daily signing.
# Run it in a real terminal (gpg asks for the key's passphrase).
#
#   scripts/signing-subkey.sh add             1. make the spare signing subkey,
#                                                put it in the keyring package
#   scripts/signing-subkey.sh backup <dir>    2. save the whole key (master + spare)
#                                                to <dir> (the Ventoy USB) and check it
#   scripts/signing-subkey.sh retire-master   3. LATER: take the master's secret
#                                                half off this PC (spare stays)
#
# Order: add -> backup -> rebuild/publish zexos-keyring (make-prebuilt.sh) ->
# wait for systems to update -> sign with the spare -> retire-master.
set -euo pipefail

FPR="${ZEXOS_SIGN_KEY:-A7806D3AD3119C44D4C1D4228DCA6BDAF6F88F95}"
KR="$(cd "$(dirname "$0")/.." && pwd)/packaging/zexos-keyring"

die() { echo "✖ $*" >&2; exit 1; }
gpg --list-secret-keys "$FPR" >/dev/null 2>&1 || die "the ZeXOS secret key is not on this computer"

case "${1:-}" in
add)
    if gpg --list-keys --with-colons "$FPR" | awk -F: '$1 == "sub" && $12 ~ /s/ {f = 1} END {exit !f}'; then
        die "a signing subkey already exists (gpg --list-keys $FPR)"
    fi
    gpg --quick-add-key "$FPR" ed25519 sign 1y
    gpg --export "$FPR" > "$KR/zexos.gpg"
    # Bump the keyring version so systems pick the update up.
    today=$(date -u +%Y%m%d)
    sed -i "s/^pkgver=.*/pkgver=$today/; s/^pkgrel=.*/pkgrel=1/" "$KR/PKGBUILD"
    echo "✔ Spare signing key made (valid 1 year) and added to $KR/zexos.gpg"
    echo "  Next: scripts/signing-subkey.sh backup /path/to/usb"
    ;;
backup)
    dir="${2:?usage: signing-subkey.sh backup <folder on the USB>}"
    [ -d "$dir" ] || die "$dir is not a folder"
    umask 077
    gpg --export-secret-keys --armor "$FPR" > "$dir/zexos-signing-full-backup.asc"
    gpg --export --armor "$FPR" > "$dir/zexos-signing-public.asc"
    # Prove the copy works: import it into an empty keyring and look.
    t=$(mktemp -d); chmod 700 "$t"
    GNUPGHOME=$t gpg --batch --import "$dir/zexos-signing-full-backup.asc" 2>/dev/null
    if GNUPGHOME=$t gpg --list-secret-keys --with-colons "$FPR" | awk -F: '$1 == "ssb" {f = 1} END {exit !f}'; then
        echo "✔ Backup works: it holds the master key and the spare. Keep it offline."
    else
        rm -rf "$t"; die "the backup does not look right, do not continue"
    fi
    rm -rf "$t"
    ;;
retire-master)
    echo "This removes the MASTER key's secret half from this computer."
    echo "Only the spare signing key stays. Make sure the USB backup is safe first."
    read -r -p "Type RETIRE to go on: " ok; [ "$ok" = RETIRE ] || die "stopped"
    t=$(mktemp -d); chmod 700 "$t"
    gpg --export-secret-subkeys "$FPR" > "$t/subkeys.gpg"
    gpg --batch --yes --delete-secret-keys "$FPR"
    gpg --batch --import "$t/subkeys.gpg" 2>/dev/null
    shred -u "$t/subkeys.gpg" 2>/dev/null || rm -f "$t/subkeys.gpg"; rmdir "$t"
    gpg --list-secret-keys "$FPR"
    echo "✔ 'sec#' above means the master secret is gone from here; 'ssb' is the spare."
    ;;
*)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
