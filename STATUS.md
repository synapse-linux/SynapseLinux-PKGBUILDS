# Packaging status

Status: source and clean x86-64-baseline package qualification passed; promotion not performed.

## Passing

- Six canonical GitHub repositories expose exact immutable source refs.
- Every recipe pins one public commit and SHA-256.
- Every committed `.SRCINFO` regenerates byte-identically.
- All source archives pass `makepkg --verifysource`.
- All six upstream test suites pass from the downloaded archives.
- The pinned Arch snapshot image uses baseline-only CRT/start files.
- Two isolated rootless Podman builds produce byte-identical packages.
- All five executables report GNU `x86 ISA needed` and `used` as
  `x86-64-baseline` only; the core shared library reports baseline-only `used`.
- PIE/shared-DYN, NX stack, GNU RELRO and BIND_NOW gates pass for all six ELF
  files.
- Package metadata declares MIT, all runtime dependencies resolve, 64 GUI
  catalogs are installed and a fresh six-package Pacman transaction passes.
- An ephemeral Distrobox with a private home passes the image/toolchain smoke
  gate.

The current CachyOS host remains unsuitable for authoritative builds because its
CRT advertises x86-64-v2/v3/v4. Host-built diagnostic packages remain rejected;
the isolated container results supersede that failed environment, not the
portability policy.

## Still separate

- The Sony VAIO has not been physically tested. The ELF result is a static
  package portability qualification, not evidence from that device.
- Packages are not signed and have not been copied to
  `SynapseLinux-Pacman-Repository`.
- Source release/tag acceptance, package signing, promotion receipt, physical
  hardware validation and OS composition remain distinct authorization gates.
