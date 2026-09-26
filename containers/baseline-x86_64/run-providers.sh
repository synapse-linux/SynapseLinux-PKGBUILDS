#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Scoped provider builds, not installation, signing or image admission.
set -euo pipefail
[[ -f /run/.containerenv && $EUID != 0 ]]
export HOME=/tmp/home XDG_RUNTIME_DIR=/tmp/runtime LANG=C.UTF-8 LC_ALL=C.UTF-8
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent
export WAYLAND_DISPLAY=synapse-package-test-missing PYTHONDONTWRITEBYTECODE=1
export SOURCE_DATE_EPOCH=1790419200 MAKEFLAGS=-j2
unset DISPLAY SSH_AUTH_SOCK
umask 022
mkdir -m700 "$HOME" "$XDG_RUNTIME_DIR"
mkdir /tmp/sources /tmp/recipes /tmp/core-sdk
cp /source-cache/*.tar.gz /tmp/sources/
cat > /tmp/makepkg.conf <<'CONF'
source /etc/makepkg.conf
CARCH=x86_64
CHOST=x86_64-pc-linux-gnu
CFLAGS='-O2 -g -march=x86-64 -mtune=generic -fstack-protector-strong'
CXXFLAGS="$CFLAGS"
LDFLAGS='-Wl,-z,relro,-z,now'
MAKEFLAGS='-j2'
BUILDENV=(!distcc color !ccache check !sign)
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug !lto)
SRCDEST=/tmp/sources
PACKAGER='Synapse Linux isolated baseline build'
COMPRESSZST=(zstd -c -T1 -19)
NPROC=1
CONF
pacman -Q > /output/builder-packages.txt
readelf -nW /usr/lib/Scrt1.o > /output/sdk-crt.txt
grep -Fq 'x86 ISA needed: x86-64-baseline' /output/sdk-crt.txt
if grep -Eq 'x86-64-v[234]' /output/sdk-crt.txt; then
    printf 'SDK startup object exceeds x86-64-baseline\n' >&2
    exit 1
fi
if pacman -Q libsynapse-core >/dev/null 2>&1; then
    printf 'The provider baseline expects an uninstalled, separately checked core SDK\n' >&2
    exit 1
fi
core=/output/libsynapse-core/libsynapse-core-0.1.0.alpha1-4-x86_64.pkg.tar.zst
core_hash=
for name in libsynapse-core synapse-background synapse-shortcuts synapse-surface synapse-workspaces; do
    mkdir "/tmp/recipes/$name" "/output/$name"
    cp "/workspace/$name/PKGBUILD" "/tmp/recipes/$name/"
    (
        cd "/tmp/recipes/$name"
        export PKGDEST="/output/$name" LOGDEST="/output/$name"
        makepkg --config /tmp/makepkg.conf --printsrcinfo > "$PKGDEST/.SRCINFO"
        cmp "$PKGDEST/.SRCINFO" "/workspace/$name/.SRCINFO"
        makepkg --config /tmp/makepkg.conf --verifysource
        dependency_args=()
        if [[ $name != libsynapse-core ]]; then
            export SYNAPSE_CORE_ROOT=/tmp/core-sdk
            python3 -B /workspace/containers/baseline-x86_64/check-provider-deps.py \
                "$PKGDEST/.SRCINFO" "$core" "$core_hash" /tmp/core-sdk
            # ALPM cannot see the staged core. The preceding mandatory gate
            # checks ALL declared requirements; no installed record is fabricated.
            dependency_args=(--nodeps)
        fi
        makepkg --config /tmp/makepkg.conf --noconfirm --cleanbuild --log "${dependency_args[@]}"
        cp PKGBUILD "$PKGDEST/PKGBUILD"
        for pkg in "$PKGDEST"/*.pkg.tar.zst; do
            bsdtar -xOf "$pkg" .PKGINFO > "$pkg.PKGINFO"
            bsdtar -xOf "$pkg" .BUILDINFO > "$pkg.BUILDINFO"
        done
    )
    if [[ $name == libsynapse-core ]]; then
        core_hash=$(sha256sum "$core"); core_hash=${core_hash%% *}
        bsdtar -xf "$core" -C /tmp/core-sdk --exclude .PKGINFO --exclude .BUILDINFO --exclude .MTREE
        printf '%s\n' "$core_hash" > /output/staged-core.sha256
    fi
done
cp /tmp/makepkg.conf /output/makepkg.conf
printf 'Five public-source packages built; signatures and runtime admission are separate.\n'
