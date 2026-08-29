#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly repo
readonly dockerfile="$repo/containers/baseline-x86_64/Dockerfile"
readonly image=${SYNAPSE_BASELINE_IMAGE:-localhost/synapse-pkgbuilds-builder:arch-20260829}
output_root=${1:-}
uid=$(id -u)
gid=$(id -g)
readonly uid gid

if [[ -z $output_root || $output_root == -* ]]; then
    printf 'usage: %s OUTPUT_DIRECTORY\n' "$0" >&2
    exit 64
fi

mkdir -p "$output_root"
output_root=$(cd "$output_root" && pwd)
[[ $output_root != "$repo" && $output_root != "$repo"/* ]] || {
    printf 'output directory must be outside the PKGBUILD repository\n' >&2
    exit 64
}
[[ -z $(find "$output_root" -mindepth 1 -print -quit) ]] || {
    printf 'output directory is not empty: %s\n' "$output_root" >&2
    exit 65
}
chmod 0700 "$output_root"
mkdir -m0700 "$output_root/a" "$output_root/b" "$output_root/receipt"

podman build \
    --pull=never \
    --platform linux/amd64 \
    --file "$dockerfile" \
    --tag "$image" \
    "$repo" 2>&1 | tee "$output_root/receipt/image-build.log"

image_id=$(podman image inspect "$image" --format '{{.Id}}')
image_digest=$(podman image inspect "$image" --format '{{.Digest}}')

podman run --rm --pull=never "$image" bash -lc '
    set -euo pipefail
    notes=$(LC_ALL=C readelf -nW /usr/lib/Scrt1.o)
    grep -q "x86 ISA needed: x86-64-baseline" <<<"$notes"
    ! grep -Eq "x86-64-v2|x86-64-v3|x86-64-v4" <<<"$notes"
    printf "%s\n" "$notes"
' > "$output_root/receipt/image-crt-properties.txt"

run_build() {
    local run=$1
    local destination="$output_root/$run"
    podman run \
        --rm \
        --pull=never \
        --name "synapse-pkgbuild-baseline-${run}-$$" \
        --userns=keep-id \
        --user "$uid:$gid" \
        --cap-drop=all \
        --security-opt=no-new-privileges \
        --read-only \
        --tmpfs /tmp:rw,nosuid,nodev,size=4g \
        --env HOME=/tmp/home \
        --env XDG_CACHE_HOME=/tmp/home/.cache \
        --env XDG_RUNTIME_DIR=/tmp/runtime \
        --env SOURCE_DATE_EPOCH=1788035241 \
        --volume "$repo:/workspace:ro" \
        --volume "$destination:/output:rw" \
        "$image" \
        bash -lc '
            install -d -m 0700 "$HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
            exec /usr/local/bin/synapse-pkgbuild-baseline /workspace /output
        ' 2>&1 | tee "$output_root/receipt/run-$run.log"
}

run_build a
run_build b

mapfile -t first < <(find "$output_root/a/packages" -maxdepth 1 -type f \
    -name '*.pkg.tar.*' -printf '%f\n' | sort)
mapfile -t second < <(find "$output_root/b/packages" -maxdepth 1 -type f \
    -name '*.pkg.tar.*' -printf '%f\n' | sort)
[[ ${#first[@]} -eq 6 && ${first[*]} == "${second[*]}" ]] || {
    printf 'package sets differ between clean builds\n' >&2
    exit 1
}

: > "$output_root/receipt/reproducibility.tsv"
for package in "${first[@]}"; do
    a_hash=$(sha256sum "$output_root/a/packages/$package" | cut -d' ' -f1)
    b_hash=$(sha256sum "$output_root/b/packages/$package" | cut -d' ' -f1)
    [[ $a_hash == "$b_hash" ]] || {
        printf 'non-reproducible package: %s\n' "$package" >&2
        exit 1
    }
    printf '%s\t%s\tidentical\n' "$package" "$a_hash" \
        >> "$output_root/receipt/reproducibility.tsv"
done

cmp "$output_root/a/reports/package-metadata.tsv" \
    "$output_root/b/reports/package-metadata.tsv"
cmp "$output_root/a/reports/qualification.env" \
    "$output_root/b/reports/qualification.env"

{
    printf 'image=%s\n' "$image"
    printf 'imageId=%s\n' "$image_id"
    printf 'imageDigest=%s\n' "$image_digest"
    printf 'platform=linux/amd64\n'
    printf 'sourceDateEpoch=1788035241\n'
    printf 'runs=2\n'
    printf 'reproduciblePackages=6\n'
    printf 'result=PASS\n'
} > "$output_root/receipt/qualification.env"

find "$output_root/receipt" "$output_root/a/reports" "$output_root/b/reports" \
    -type f -printf '%p\0' | sort -z | xargs -0 sha256sum \
    > "$output_root/receipt/evidence-sha256.txt"

printf 'Clean Podman baseline builds: PASS\n'
cat "$output_root/receipt/qualification.env"
cat "$output_root/receipt/reproducibility.tsv"
