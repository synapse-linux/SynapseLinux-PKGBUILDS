#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1788035241}"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
umask 022

readonly input=${1:-/workspace}
readonly output=${2:-/output}
readonly work_root=/tmp/synapse-pkgbuild-baseline
readonly repo="$work_root/repo"
readonly core_root="$work_root/core-root"
readonly stage="$work_root/stage"
readonly packages="$output/packages"
readonly sources="$output/sources"
readonly logs="$output/logs"
readonly reports="$output/reports"
readonly makepkg_config="$work_root/makepkg.conf"

cleanup() {
    rm -rf -- "$work_root"
}
trap cleanup EXIT

fail() {
    printf 'baseline build gate failed: %s\n' "$*" >&2
    exit 1
}

[[ -r "$input/packages.order" ]] || fail "missing packages.order in $input"
[[ ! -e $work_root ]] || fail "fixed build root already exists: $work_root"
mkdir -p "$repo" "$core_root" "$stage" "$packages" "$sources" "$logs" "$reports"
[[ -z $(find "$packages" -mindepth 1 -print -quit) ]] || fail "package output is not empty"
cp /etc/makepkg.conf "$makepkg_config"
printf '\n# Serialize package tidying under fakeroot. Compilation still uses MAKEFLAGS.\nNPROC=1\n' \
    >> "$makepkg_config"

tar \
    --exclude=.git \
    --exclude='*/src' \
    --exclude='*/pkg' \
    --exclude='*.pkg.tar.*' \
    --exclude='*.src.tar.*' \
    -C "$input" -cf - . | tar -C "$repo" -xf -

export PKGDEST=$packages
export SRCDEST=$sources
export SRCPKGDEST=$output/source-packages
export LOGDEST=$logs
mkdir -p "$SRCPKGDEST"

make -C "$repo" check-metadata
make -C "$repo" verify-sources
shellcheck "$repo"/tools/*.sh "$repo"/containers/baseline-x86_64/run-build.sh

source_directory() {
    local package=$1
    local result
    result=$(find "$repo/$package/src" -mindepth 1 -maxdepth 1 -type d \
        -name "$package-*" -print -quit)
    [[ -n $result ]] || fail "source directory not found for $package"
    printf '%s\n' "$result"
}

package_file() {
    local package=$1
    local result
    result=$(find "$packages" -maxdepth 1 -type f \
        -name "$package-[0-9]*.pkg.tar.*" -print | sort | tail -n 1)
    [[ -n $result ]] || fail "package archive not found for $package"
    printf '%s\n' "$result"
}

build_package() {
    local package=$1
    shift
    printf '==> Clean baseline build: %s\n' "$package"
    (
        cd "$repo/$package"
        env "$@" makepkg --config "$makepkg_config" \
            --cleanbuild --force --nodeps --noconfirm --log
    )
    package_file "$package" >/dev/null
}

build_package libsynapse-core
core_package=$(package_file libsynapse-core)
bsdtar -xf "$core_package" -C "$core_root"

for package in synapse-doc synapse-chart; do
    build_package "$package" "SYNAPSE_CORE_ROOT=$core_root"
done
build_package synapse-editor

doc_source=$(source_directory synapse-doc)
doc_binary="$doc_source/build/synapse-doc"
[[ -x $doc_binary ]] || fail "Doc provider is not executable"
build_package synapse-knowledge \
    "SYNAPSE_CORE_ROOT=$core_root" \
    "DOC_BINARY=$doc_binary"

chart_source=$(source_directory synapse-chart)
editor_source=$(source_directory synapse-editor)
knowledge_source=$(source_directory synapse-knowledge)
chart_binary="$chart_source/build/synapse-chart"
editor_binary="$editor_source/build/synapse-editor"
knowledge_binary="$knowledge_source/build/synapse-knowledge"
for provider in "$chart_binary" "$editor_binary" "$knowledge_binary"; do
    [[ -x $provider ]] || fail "provider is not executable: $provider"
done

build_package synapse-knowledge-gui \
    "KNOWLEDGE_BINARY=$knowledge_binary" \
    "EDITOR_BINARY=$editor_binary" \
    "DOC_BINARY=$doc_binary" \
    "CHART_BINARY=$chart_binary" \
    "LD_LIBRARY_PATH=$core_root/usr/lib"

mapfile -t package_files < <(find "$packages" -maxdepth 1 -type f \
    -name '*.pkg.tar.*' -print | sort)
[[ ${#package_files[@]} -eq 6 ]] || fail "expected 6 packages, found ${#package_files[@]}"

: > "$reports/package-metadata.tsv"
for archive in "${package_files[@]}"; do
    metadata=$(bsdtar -xOf "$archive" .PKGINFO)
    name=$(awk -F ' = ' '$1 == "pkgname" {print $2}' <<<"$metadata")
    version=$(awk -F ' = ' '$1 == "pkgver" {print $2}' <<<"$metadata")
    license=$(awk -F ' = ' '$1 == "license" {print $2}' <<<"$metadata" | paste -sd, -)
    [[ $license == MIT ]] || fail "$name package license is $license, expected MIT"
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$name" "$version" "$license" "$(stat -c %s "$archive")" \
        "$(sha256sum "$archive" | cut -d' ' -f1)" \
        >> "$reports/package-metadata.tsv"
    bsdtar -xf "$archive" -C "$stage" \
        --exclude .BUILDINFO --exclude .MTREE --exclude .PKGINFO
    namcap "$archive" >> "$reports/namcap.txt" 2>&1 || true
done

[[ $(find "$stage/usr/share/licenses" -type f -name LICENSE | wc -l) -eq 6 ]] \
    || fail "expected six packaged license files"
while IFS= read -r -d '' license_file; do
    [[ $(head -n 1 "$license_file") == 'MIT License' ]] \
        || fail "non-MIT packaged license: $license_file"
done < <(find "$stage/usr/share/licenses" -type f -name LICENSE -print0)

[[ $(find "$stage" -type f -perm /022 | wc -l) -eq 0 ]] \
    || fail "group/world-writable packaged regular file"
if grep -aR -E '/home/|/tmp/synapse-pkgbuild-baseline\.' "$stage" >/dev/null; then
    fail "host or ephemeral build path embedded in package content"
fi

while IFS= read -r -d '' link; do
    target=$(readlink "$link")
    [[ $target != /* && $target != *'..'* ]] || fail "unsafe package symlink: $link -> $target"
done < <(find "$stage" -type l -print0)

catalog_count=$(find "$stage/usr/share/synapse-knowledge-gui/i18n" \
    -maxdepth 1 -type f -name '*.qm' | wc -l)
[[ $catalog_count -eq 64 ]] || fail "expected 64 GUI catalogs, found $catalog_count"

while IFS= read -r -d '' desktop; do
    desktop-file-validate "$desktop"
done < <(find "$stage/usr/share/applications" -type f -name '*.desktop' -print0)
while IFS= read -r -d '' mime_file; do
    xmllint --noout "$mime_file"
done < <(find "$stage/usr/share/mime/packages" -type f -name '*.xml' -print0)

: > "$reports/elf-properties.txt"
mapfile -t elf_files < <(
    find "$stage/usr/bin" "$stage/usr/lib" -type f -print0 \
        | xargs -0 file \
        | awk -F: '/ELF 64-bit/ {print $1}' \
        | sort
)
[[ ${#elf_files[@]} -eq 6 ]] || fail "expected six packaged ELF files, found ${#elf_files[@]}"

for binary in "${elf_files[@]}"; do
    relative=${binary#"$stage"}
    notes=$(readelf -nW "$binary")
    headers=$(readelf -hW "$binary")
    programs=$(readelf -lW "$binary")
    dynamic=$(readelf -dW "$binary")

    {
        printf '===%s===\n' "$relative"
        file "$binary"
        grep -E 'Class:|Type:|Machine:' <<<"$headers"
        grep -E 'GNU_STACK|GNU_RELRO' <<<"$programs"
        grep -E 'BIND_NOW|FLAGS_1|SONAME' <<<"$dynamic" || true
        grep -E 'x86 ISA needed|x86 ISA used|Build ID' <<<"$notes" || true
    } >> "$reports/elf-properties.txt"

    grep -q 'Machine:.*Advanced Micro Devices X86-64' <<<"$headers" \
        || fail "$relative is not x86-64"
    grep -q 'Type:.*DYN' <<<"$headers" || fail "$relative is not PIE/shared DYN"
    grep -q 'GNU_RELRO' <<<"$programs" || fail "$relative lacks GNU_RELRO"
    stack=$(grep 'GNU_STACK' <<<"$programs")
    [[ $stack != *RWE* ]] || fail "$relative has executable stack"
    grep -q 'BIND_NOW' <<<"$dynamic" || fail "$relative lacks BIND_NOW"
    if grep -Eq 'x86-64-v2|x86-64-v3|x86-64-v4' <<<"$notes"; then
        fail "$relative requires or uses an ISA above x86-64-baseline"
    fi
    if [[ $relative == /usr/bin/* ]]; then
        grep -q 'x86 ISA needed: x86-64-baseline' <<<"$notes" \
            || fail "$relative lacks an explicit baseline-only ISA requirement"
    fi
    if ! LD_LIBRARY_PATH="$stage/usr/lib" ldd "$binary" \
        > "$reports/ldd-$(basename "$binary").txt" 2>&1; then
        fail "ldd failed for $relative"
    fi
    if grep -q 'not found' "$reports/ldd-$(basename "$binary").txt"; then
        fail "unresolved dependency for $relative"
    fi
done

find "$stage" -printf '%m\t%u:%g\t%y\t%P\t%l\n' \
    | sort > "$reports/install-manifest.tsv"
sha256sum "${package_files[@]}" | sort -k2 > "$reports/package-sha256.txt"
pacman -Q > "$reports/build-environment-packages.txt"
cp /etc/os-release "$reports/os-release.txt"
{
    printf 'sourceDateEpoch=%s\n' "$SOURCE_DATE_EPOCH"
    printf 'packageCount=%s\n' "${#package_files[@]}"
    printf 'elfCount=%s\n' "${#elf_files[@]}"
    printf 'catalogCount=%s\n' "$catalog_count"
    printf 'licenseCount=6\n'
    printf 'groupWorldWritableFiles=0\n'
    printf 'hostPaths=0\n'
    printf 'isa=x86-64-baseline\n'
    printf 'result=PASS\n'
} > "$reports/qualification.env"

printf 'Synapse baseline package qualification: PASS\n'
cat "$reports/qualification.env"
