# Changing the ZeXOS signing key (rotation)

The current key's fingerprint is in `zexos-trusted`. Systems trust a key
because it is listed there: `pacman-key --populate zexos` signs every listed key
locally. So a new key is trusted once a `zexos-keyring` update lists it — and
that update can only be installed because it is signed with the old key, which
is what carries the trust over. (The old key also signs the new one, step 2, so
anyone can check by hand that it really comes from ZeXOS. On its own that
signature is not enough for pacman: `:4:` in `zexos-trusted` means "marginal"
trust, and pacman wants three marginal signers, like Arch's packager keys.)

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
