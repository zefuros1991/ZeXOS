# Changing the ZeXOS signing key (rotation)

The current key's fingerprint is in `zexos-trusted`. Systems trust it fully
(`pacman-key --populate zexos` locally signs it). A new key is trusted because
the old, trusted key signs it — the same web of trust Arch uses for packagers.

1. Create the new key on the maintainer's computer (passphrase, offline backup
   on the Ventoy USB, as the first key).
2. Sign the new key with the old one: `gpg --quick-sign-key <NEW_FPR>` (uses
   the old key's passphrase).
3. Export both: `gpg --export <OLD_FPR> <NEW_FPR> > zexos.gpg`, add the new
   fingerprint to `zexos-trusted` (`<NEW_FPR>:4:`), bump `pkgver`.
4. Build and publish `zexos-keyring` signed with the OLD key; wait for systems
   to update (at least one release cycle).
5. Only then sign packages with the new key. To retire the old key, move its
   fingerprint to `zexos-revoked` in a later keyring release.

If the key is stolen: publish its revocation certificate (on the Ventoy USB)
and a keyring release that lists it in `zexos-revoked`, signed with a new key
that was cross-signed before the loss, or announce the new fingerprint on the
ZeXOS GitHub page so users can verify it by hand.

Tested by check AC-27.1 (`checks/lib/rotation-test.sh`) with throwaway keys.
