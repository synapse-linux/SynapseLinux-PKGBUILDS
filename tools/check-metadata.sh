#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d /tmp/synapse-pkgbuild-metadata.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

count=0
while IFS= read -r package || [[ -n $package ]]; do
  [[ -z $package || $package == \#* ]] && continue
  directory=$ROOT/$package
  if [[ ! -f $directory/PKGBUILD || ! -f $directory/.SRCINFO ]]; then
    echo "error: missing PKGBUILD or .SRCINFO for $package" >&2
    exit 1
  fi
  generated=$WORK/$package.SRCINFO
  (cd "$directory" && makepkg --printsrcinfo) >"$generated"
  if ! cmp -s "$generated" "$directory/.SRCINFO"; then
    echo "error: stale .SRCINFO for $package" >&2
    diff -u "$directory/.SRCINFO" "$generated" >&2 || true
    exit 1
  fi
  ((count++)) || true
done <"$ROOT/packages.order"

printf 'Validated metadata for %d package(s).\n' "$count"
