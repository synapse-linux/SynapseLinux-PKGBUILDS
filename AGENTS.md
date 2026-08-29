# SynapseLinux PKGBUILDS agent contract

- This repository owns Arch package recipes only. Application and library source
  histories remain in their individual `synapse-linux/*` repositories.
- Keep one directory per independently versioned package/source project.
- Fetch immutable public commits or signed release tags from the canonical
  GitHub repository. `SKIP`, mutable branches and `latest` are forbidden.
- Every source URL and SHA-256 must be exact, and `.SRCINFO` must match its
  `PKGBUILD` byte-for-byte after regeneration.
- First-party Synapse source projects use the MIT License. Packages for imported
  or third-party projects must preserve and declare the actual upstream license;
  never relabel external code as MIT.
- Do not commit downloaded source archives, built packages, `src/`, `pkg/`,
  signing keys, credentials or host-local state.
- Preserve dependency order in `packages.order`; dependency declarations remain
  authoritative for package managers.
- Versioned package filenames are immutable. A new source under the same
  upstream version requires a `pkgrel` increment.
- Production promotion requires signed source identity, signed packages,
  content-addressed retention and a separate release receipt.
- This packaging repository uses a single `main` branch. Standard Git Flow is
  reserved for the individual project source repositories.
- Generated scripts, documentation and diagnostics are written in English.
- Do not push, tag, sign, publish, install or mutate a live Pacman repository
  without explicit authorization.
