#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Dependency gate controls; mock ALPM/metadata responses are not admission."""
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('deps',ROOT/'containers/baseline-x86_64/check-provider-deps.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


class Dependencies(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        root=Path(self.temp.name);self.stage=root/'stage';self.stage.mkdir()
        self.archive=root/'core.pkg';self.archive.write_bytes(b'controlled-test-archive')
        self.sha=hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.srcinfo=root/'srcinfo'
        self.srcinfo.write_text('depends = libsynapse-core\ndepends = glibc\nmakedepends = gcc\ncheckdepends = python\n')
        self.members={'usr/include/synapse/core.h':b'header','usr/lib/libsynapse-core.so.0.1.0':b'library'}
        for rel,data in self.members.items():
            p=self.stage/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
        (self.stage/'usr/lib/libsynapse-core.so.0').symlink_to('libsynapse-core.so.0.1.0')
        self.info='pkgname = libsynapse-core\npkgver = 0.1.0.alpha1-4\nprovides = libsynapse-core.so=0-64\nlicense = MIT\n'

    def output(self,argv,**kw):
        if argv[0]=='bsdtar':return self.info if argv[-1]=='.PKGINFO' else self.members[argv[-1]]
        self.assertEqual(argv[0],'readelf')
        return 'Library soname: [libsynapse-core.so.0]'

    def check(self):return m.check(self.srcinfo,self.archive,self.sha,self.stage)

    def test_all_mandatory_dependencies_checked(self):
        with patch.object(m.subprocess,'check_output',self.output), patch.object(m.subprocess,'run') as run:
            self.assertEqual(self.check(),['gcc','glibc','python'])
            run.assert_called_once_with(['pacman','-T','gcc','glibc','python'],check=True,timeout=20)

    def test_changed_archive_rejected_before_external_commands(self):
        self.archive.write_bytes(b'changed')
        with patch.object(m.subprocess,'check_output') as command:
            with self.assertRaisesRegex(ValueError,'archive changed'):self.check()
            command.assert_not_called()

    def test_missing_mandatory_dependency_is_not_ignored(self):
        with patch.object(m.subprocess,'check_output',self.output), patch.object(m.subprocess,'run',side_effect=subprocess.CalledProcessError(127,['pacman'])):
            with self.assertRaises(subprocess.CalledProcessError):self.check()

    def test_altered_staged_library_rejected(self):
        (self.stage/'usr/lib/libsynapse-core.so.0.1.0').write_bytes(b'changed')
        with patch.object(m.subprocess,'check_output',self.output), patch.object(m.subprocess,'run'):
            with self.assertRaisesRegex(ValueError,'staged core changed'):self.check()

    def test_unknown_core_version_rejected(self):
        self.info=self.info.replace('alpha1-4','alpha1-3')
        with patch.object(m.subprocess,'check_output',self.output):
            with self.assertRaisesRegex(ValueError,'core metadata'):self.check()

    def test_dependency_cannot_be_an_option(self):
        self.srcinfo.write_text('depends = libsynapse-core\ncheckdepends = --help\n')
        with patch.object(m.subprocess,'check_output',self.output), patch.object(m.subprocess,'run') as run:
            with self.assertRaisesRegex(ValueError,'invalid dependency'):self.check()
            run.assert_not_called()

    def test_arch_specific_requirements_are_checked_not_silently_dropped(self):
        self.srcinfo.write_text('depends = libsynapse-core\ndepends_x86_64 = glibc\n')
        with patch.object(m.subprocess,'check_output',self.output), patch.object(m.subprocess,'run') as run:
            self.assertEqual(self.check(),['glibc'])
        self.srcinfo.write_text('depends = libsynapse-core\ndepends_aarch64 = other\n')
        with patch.object(m.subprocess,'check_output',self.output):
            with self.assertRaisesRegex(ValueError,'architecture'):self.check()

    def test_symlinked_metadata_rejected(self):
        other=self.srcinfo.with_name('other');other.write_bytes(self.srcinfo.read_bytes())
        self.srcinfo.unlink();self.srcinfo.symlink_to(other)
        with self.assertRaisesRegex(ValueError,'dependency metadata'):self.check()


if __name__=='__main__':unittest.main()
