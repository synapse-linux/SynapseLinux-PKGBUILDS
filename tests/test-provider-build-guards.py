#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Exercise actual shell guard blocks with synthetic notes, not ISA admission."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]


class Guards(unittest.TestCase):
    def sdk_gate(self,notes):
        text=(ROOT/'containers/baseline-x86_64/run-providers.sh').read_text()
        block=text[text.index('readelf -nW'):text.index('if pacman -Q libsynapse-core')]
        with tempfile.TemporaryDirectory() as directory:
            block=block.replace('/output/sdk-crt.txt',str(Path(directory)/'notes.txt'))
            program='readelf() { printf "%s\\n" "$TEST_NOTES"; }\n'+block+'\nprintf "gate-continued\\n"\n'
            return subprocess.run(['bash','-euo','pipefail','-c',program],
                                  env={**os.environ,'TEST_NOTES':notes},capture_output=True,text=True,timeout=5)

    def test_baseline_crt_reaches_build(self):
        p=self.sdk_gate('x86 ISA needed: x86-64-baseline')
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertIn('gate-continued',p.stdout)

    def test_higher_needed_or_used_isa_stops_before_build(self):
        for note in ('x86 ISA needed: x86-64-baseline, x86-64-v2',
                     'x86 ISA needed: x86-64-baseline\nx86 ISA used: x86-64-v3',
                     'x86 ISA needed: x86-64-baseline\nx86 ISA used: x86-64-v4'):
            with self.subTest(note=note):
                p=self.sdk_gate(note)
                self.assertNotEqual(p.returncode,0)
                self.assertNotIn('gate-continued',p.stdout)

    def test_missing_baseline_note_stops_before_build(self):
        p=self.sdk_gate('no architecture requirement')
        self.assertNotEqual(p.returncode,0)
        self.assertNotIn('gate-continued',p.stdout)

    def test_existing_output_is_not_reused(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);output=root/'output';output.mkdir();cache=root/'cache';cache.mkdir()
            marker=output/'retained';marker.write_text('unchanged')
            p=subprocess.run(['bash',str(ROOT/'tools/build-providers-baseline.sh'),str(output),str(cache)],
                             capture_output=True,timeout=5)
            self.assertNotEqual(p.returncode,0)
            self.assertEqual(list(output.iterdir()),[marker])
            self.assertEqual(marker.read_text(),'unchanged')


if __name__=='__main__':unittest.main()
