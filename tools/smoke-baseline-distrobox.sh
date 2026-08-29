#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

readonly image=${SYNAPSE_BASELINE_IMAGE:-localhost/synapse-pkgbuilds-builder:arch-20260829}
readonly name="synapse-pkgbuild-baseline-smoke-$$"
home=$(mktemp -d /tmp/synapse-pkgbuild-distrobox-home.XXXXXX)
readonly home
report=${1:-}
remove_report=0
if [[ -z $report ]]; then
    report=$(mktemp /tmp/synapse-pkgbuild-distrobox-report.XXXXXX)
    remove_report=1
fi
created=0

cleanup() {
    if (( created )); then
        distrobox-rm --force "$name" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$home"
    if (( remove_report )); then
        rm -f -- "$report"
    fi
}
trap cleanup EXIT

podman image exists "$image" || {
    printf 'missing image: %s\n' "$image" >&2
    exit 66
}

DBX_NON_INTERACTIVE=1 distrobox-create \
    --yes \
    --image "$image" \
    --name "$name" \
    --home "$home" \
    --no-entry \
    --unshare-all
created=1

# Variables in this command are intentionally evaluated inside the distrobox.
# shellcheck disable=SC2016
distrobox-enter --no-tty --clean-path --name "$name" -- bash -lc '
    set -euo pipefail
    export LC_ALL=C
    notes=$(readelf -nW /usr/lib/Scrt1.o)
    grep -q "x86 ISA needed: x86-64-baseline" <<<"$notes"
    ! grep -Eq "x86-64-v2|x86-64-v3|x86-64-v4" <<<"$notes"
    command -v makepkg
    command -v qmake6
    command -v lrelease6
    command -v sqlite3
    command -v shellcheck
    printf "uid=%s\n" "$(id -u)"
    printf "isa=x86-64-baseline\n"
    printf "result=PASS\n"
' > "$report"

cat "$report"
