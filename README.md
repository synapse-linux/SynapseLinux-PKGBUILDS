# SynapseLinux PKGBUILDS

Canonical Arch package recipes for independently versioned Synapse Linux source
projects.

Application and library code lives in the corresponding public project
repository. This repository stores only `PKGBUILD`, generated `.SRCINFO` and
bounded packaging documentation; downloaded archives and built packages are not
committed.

## Initial project set

| Build order | Package | Canonical source |
|---:|---|---|
| 1 | `libsynapse-core` | <https://github.com/synapse-linux/libsynapse-core> |
| 2 | `synapse-doc` | <https://github.com/synapse-linux/synapse-doc> |
| 3 | `synapse-chart` | <https://github.com/synapse-linux/synapse-chart> |
| 4 | `synapse-editor` | <https://github.com/synapse-linux/synapse-editor> |
| 5 | `synapse-knowledge` | <https://github.com/synapse-linux/synapse-knowledge> |
| 6 | `synapse-knowledge-gui` | <https://github.com/synapse-linux/synapse-knowledge-gui> |

`packages.order` is the deterministic build order. Each recipe also declares
its actual package-manager dependencies.

All initial sources are pinned to public immutable commits. The project source
repositories use Git Flow: `main` remains the accepted release line and
`develop` contains the latest qualified integration. Packaging a `develop`
commit does not claim that it is a released or signed source tag.

These six first-party projects are licensed under MIT on their current
`develop` commits. Future recipes for external projects must retain their actual
upstream licenses rather than inheriting the Synapse default.

## Validation

```sh
make verify-sources
make check-metadata
```

`verify-sources` downloads each exact archive and verifies its SHA-256.
`check-metadata` regenerates `.SRCINFO` into a temporary file and compares it
with the committed metadata.

Package builds and release publication are separate gates. Built packages
belong in `SynapseLinux-Pacman-Repository`, never in this repository. See
[`STATUS.md`](STATUS.md) for current promotion blockers.
