<!-- SPDX-License-Identifier: MIT -->
# Scoped C provider baseline

This profile builds core plus Background, Shortcuts, Surface and Workspaces from
immutable public source archives. It does not change the existing Knowledge-stack
runner or qualify unrelated recipes. Source projects keep independent histories.

`providers-sdk.json` pins the exact prepared rootless image. It was derived
**directly from the canonical baseline image**, not the previous private Settings
SDK, by a normal offline ALPM transaction of the 139 signed Arch inputs recorded
in `providers-sdk-inputs.json`. The lock includes exact archive sizes, hashes and
signature bytes. The canonical base's 2026/08/29 label is not a claim that its
upgraded provider SDK still has that snapshot's package inventory. The effective
inventory is recorded with every build.

To reconstruct/qualify an SDK, first build/verify the canonical pinned base under
this directory, acquire the exact public lock inputs, validate all detached
signatures with authenticated Arch trust roots, then apply the complete transaction
in a disposable rootless container with `LocalFileSigLevel = Required TrustedOnly`.
Retain the complete dependency check, transaction status, installed inventory and
new immutable image identity. Do not replace the profile's image ID merely because
a tag or Dockerfile name matches. A reconstructed image needs its own reviewed
identity; this profile does not publish an OCI image or promise identical container
layer timestamps. Do not carry private keys, host trust state or sessions into it.

With the exact prepared SDK and a source cache whose files match the five recipes:

```sh
./tools/build-providers-baseline.sh /new/output /verified/source-cache
```

The driver refuses an existing output, uses two separate offline, read-only-root,
non-root containers, bounds CPU/memory/PIDs, has no host session/device mounts and
compares all five archive SHA256 values. Sources are copied to private temporary
build roots and makepkg verifies the canonical URL/hash declarations without a
network fallback. Source publication may be newer than the deterministic build
metadata epoch; that epoch is not the wall-clock qualification timestamp.

Core is built first and used as an **uninstalled staged SDK**, as in the existing
baseline model. Before each provider's `--nodeps` build, the mandatory gate checks
all depends/makedepends/checkdepends through normal ALPM, plus the exact core
archive identity, metadata, installed-header/library bytes and SONAME. No installed
core record is fabricated and package-signature policy is not relaxed. The
`.BUILDINFO` installed-package list therefore needs the separate staged-core hash
and recipe/source/build receipt; it does not establish runtime dependencies.

The reproducibility result is deliberately not an admission receipt. Qualification
also requires strict GCC/Clang, meaningful analyzers/sanitizers, headless suites,
packaged locale controls, notices/payload layout, ELF baseline/PIE-RELRO-NOW,
non-executable stack, no RPATH/RUNPATH and declared shared-dependency checks.
Canonical package filenames are immutable; these new public-source recipes advance
pkgrel beyond the preceding private candidates, including core. Signing, source
identity attestation, content-addressed retention, complete image role resolution,
installed/native behavior and release/deployment authorization are separate gates.
