# Packaging status

Status: source-qualified staging; binary promotion blocked.

## Passing

- Six canonical GitHub repositories expose exact `main` and `develop` refs.
- Every recipe pins one immutable public `develop` commit and SHA-256.
- Every committed `.SRCINFO` regenerates byte-identically.
- All source archives pass `makepkg --verifysource`.
- All six upstream test suites pass from the downloaded archives.
- Two consecutive host builds produced byte-identical packages.
- Package metadata declares MIT for the six first-party sources.

## Blocking binary promotion

The current CachyOS host links startup/runtime objects whose GNU property reports
`x86 ISA needed: x86-64-baseline, x86-64-v2, x86-64-v3, x86-64-v4` for the five
executables, even though every recipe passes `-march=x86-64 -mtune=generic`.
Those host-built packages are therefore rejected for Synapse's x86-64-baseline
target and must not enter `SynapseLinux-Pacman-Repository`.

Rebuild in a qualified clean x86-64-baseline Arch environment, rerun upstream
tests, reproducibility, full ELF-property and package-content gates, then sign
and promote through a separate authorization. The local diagnostic package
outputs are disposable evidence and are not committed or published.
