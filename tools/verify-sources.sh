#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SOURCE_CACHE=$(mktemp -d /tmp/synapse-pkgbuild-sources.XXXXXX)
trap 'rm -rf "$SOURCE_CACHE"' EXIT
export SRCDEST=$SOURCE_CACHE

count=0
while IFS= read -r package || [[ -n $package ]]; do
  [[ -z $package || $package == \#* ]] && continue
  directory=$ROOT/$package
  if [[ ! -f $directory/PKGBUILD ]]; then
    echo "error: missing PKGBUILD for $package" >&2
    exit 1
  fi
  echo "Verifying $package ..."
  (cd "$directory" && makepkg --verifysource --noconfirm)
  ((count++)) || true
done <"$ROOT/packages.order"

printf 'Verified immutable sources for %d package(s).\n' "$count"
