#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check every mandatory SDK dependency and the exact uninstalled core SDK.

This does not create an ALPM installed record or admit an image runtime.
"""
import hashlib
from pathlib import Path
import re
import subprocess
import sys


def check(srcinfo, core, expected_sha256, stage):
    if not re.fullmatch(r'[a-f0-9]{64}', expected_sha256):
        raise ValueError('invalid core archive identity')
    if core.is_symlink() or not core.is_file() or core.stat().st_size > 1024**2:
        raise ValueError('invalid core archive')
    if hashlib.sha256(core.read_bytes()).hexdigest() != expected_sha256:
        raise ValueError('core archive changed')
    if srcinfo.is_symlink() or not srcinfo.is_file() or srcinfo.stat().st_size > 65536:
        raise ValueError('invalid dependency metadata or size exceeds bound')
    fields = {}
    info = subprocess.check_output(['bsdtar', '-xOf', str(core), '.PKGINFO'], timeout=20, text=True)
    for line in info.splitlines():
        key, sep, value = line.partition(' = ')
        if sep: fields.setdefault(key, []).append(value)
    for key, value in [('pkgname','libsynapse-core'), ('pkgver','0.1.0.alpha1-4'),
                       ('provides','libsynapse-core.so=0-64'), ('license','MIT')]:
        if fields.get(key) != [value]: raise ValueError('unexpected core metadata: ' + key)
    requirements = set()
    kinds = ('depends', 'makedepends', 'checkdepends')
    for line in srcinfo.read_text().splitlines():
        key, sep, value = line.strip().partition(' = ')
        if not sep: continue
        if key in kinds or key in {k + '_x86_64' for k in kinds}:
            if not re.fullmatch(r'[a-z0-9][a-zA-Z0-9@+_.:~<>=-]{0,255}', value):
                raise ValueError('invalid dependency')
            requirements.add(value)
        elif any(key.startswith(k + '_') for k in kinds):
            raise ValueError('unsupported dependency architecture')
    if 'libsynapse-core' not in requirements: raise ValueError('core dependency missing')
    requirements.remove('libsynapse-core')
    subprocess.run(['pacman', '-T', *sorted(requirements)], check=True, timeout=20)
    stage = stage.resolve(strict=True)
    for rel in ('usr/include/synapse/core.h', 'usr/lib/libsynapse-core.so.0.1.0'):
        path = stage / rel
        if not path.resolve(strict=True).is_relative_to(stage):
            raise ValueError('staged core path escapes SDK')
        original = subprocess.check_output(['bsdtar', '-xOf', str(core), rel], timeout=20)
        if path.read_bytes() != original: raise ValueError('staged core changed: ' + rel)
    link = stage / 'usr/lib/libsynapse-core.so.0'
    if link.resolve(strict=True) != stage / 'usr/lib/libsynapse-core.so.0.1.0':
        raise ValueError('unexpected staged core link')
    text = subprocess.check_output(['readelf', '-d', str(link)], timeout=20, text=True)
    if 'Library soname: [libsynapse-core.so.0]' not in text:
        raise ValueError('core SONAME changed')
    return sorted(requirements)


if __name__ == '__main__':
    try:
        srcinfo, core, expected, stage = sys.argv[1:]
        deps = check(Path(srcinfo), Path(core), expected, Path(stage))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print('Provider SDK dependency gate failed: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
    print('Provider SDK dependencies checked; core remains uninstalled:', expected)
