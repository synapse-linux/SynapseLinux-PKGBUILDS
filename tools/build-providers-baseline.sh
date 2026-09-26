#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Two clean offline runs against the exact prepared provider SDK identity.
set -euo pipefail
export LC_ALL=C
umask 077
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $# != 2 || $1 == -* || $2 == -* ]]; then
    printf 'Usage: %s NEW_OUTPUT_DIRECTORY VERIFIED_SOURCE_CACHE\n' "$0" >&2
    exit 64
fi
output=$(realpath -m -- "$1")
cache=$(realpath -e -- "$2")
[[ ! -e $output && ! -L $output && -d $cache && $output != "$repo"/* ]]
[[ $output != "$cache" && $output != "$cache"/* ]]
profile="$repo/containers/baseline-x86_64/providers-sdk.json"
image=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["imageId"])' "$profile")
[[ $image =~ ^[0-9a-f]{64}$ ]]
podman image exists "$image"
mkdir -p -- "$output"
cp "$profile" "$output/sdk-profile.json"
for run in a b; do
    mkdir -m700 "$output/$run"
    podman run --rm --pull=never --network=none --read-only \
        --userns=keep-id --user "$(id -u):$(id -g)" \
        --cap-drop=ALL --security-opt=no-new-privileges \
        --cpus=2 --memory=3g --memory-swap=3g --pids-limit=256 --ulimit=core=0 \
        --tmpfs=/tmp:rw,nosuid,nodev,size=1g,mode=1777 \
        -v "$repo:/workspace:ro" -v "$cache:/source-cache:ro" -v "$output/$run:/output:rw" \
        "$image" bash /workspace/containers/baseline-x86_64/run-providers.sh \
        >"$output/run-$run.log" 2>&1
done
python3 - "$output" <<'PY'
import hashlib,json
from pathlib import Path
import sys
root=Path(sys.argv[1]);a=sorted((root/'a').glob('*/*.pkg.tar.zst'));b=sorted((root/'b').glob('*/*.pkg.tar.zst'))
assert len(a)==len(b)==5
assert [p.name for p in a]==[p.name for p in b]
rows=[]
for first,second in zip(a,b):
    h=hashlib.sha256(first.read_bytes()).hexdigest()
    assert h==hashlib.sha256(second.read_bytes()).hexdigest(), first.name
    rows.append(dict(filename=first.name,sha256=h,bytes=first.stat().st_size,reproducible=True))
with (root/'reproducibility.json').open('x') as f:
    json.dump(dict(result='PASS_TWO_OFFLINE_PUBLIC_SOURCE_BUILDS',packages=rows,
                   signingPerformed=False,runtimeAdmitted=False,payloadQualificationSeparate=True),f,indent=2)
    f.write('\n')
print('Two clean offline provider builds are byte-identical; not runtime admission.')
PY
