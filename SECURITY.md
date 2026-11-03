# Security

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Use GitHub's private report instead: on the [Security tab](https://github.com/zefuros1991/ZeXOS/security) choose **Report a vulnerability**. Only the maintainer can see the report, and nothing is public until the problem is fixed.

Say what you found, how to reproduce it and which version or branch you tested.

## Supported versions

Fixes go into the latest release. Older releases are not patched.

## Signed packages

ZeXOS's own packages are signed. The ready-made package repo is checked against checksums kept in `packaging/prebuilt.list`, and the installer falls back to building from source when a check fails.

[Back to the README](README.md)
