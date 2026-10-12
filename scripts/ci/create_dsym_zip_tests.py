#!/usr/bin/env python3
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT_PATH = Path(__file__).with_name("create-dsym-zip.sh")
# Two Mach-O binaries present on every macOS machine, standing in for builds with different UUIDs.
# The script only reads their `LC_UUID`, so any pair works.
SHIPPED_BINARY = Path("/bin/ls")
OTHER_BUILD_BINARY = Path("/bin/cat")


class CreateDsymZipTests(unittest.TestCase):
    """A dSYM that does not match the shipped binary symbolicates nothing, and the mismatch surfaces
    only when someone needs a crash report, long after the runner that built it is gone."""

    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        root = Path(self.temporary_directory.name)
        self.export_path = root / "export"
        self.release_path = root / "release"
        self.github_output = root / "github_output"
        self.github_output.touch()
        self.app_dsym = self.export_path / "Caffeinate.app.dSYM"
        dwarf = self.app_dsym / "Contents" / "Resources" / "DWARF"
        dwarf.mkdir(parents=True)
        shutil.copy(SHIPPED_BINARY, dwarf / "Caffeinate")
        self.app_binary = self.export_path / "Caffeinate.app" / "Contents" / "MacOS" / "Caffeinate"
        self.app_binary.parent.mkdir(parents=True)
        shutil.copy(SHIPPED_BINARY, self.app_binary)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def run_script(self) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment.update(
            EXPORT_PATH=str(self.export_path),
            RELEASE_PATH=str(self.release_path),
            APP_NAME="Caffeinate",
            GITHUB_OUTPUT=str(self.github_output),
        )
        return subprocess.run([str(SCRIPT_PATH)], check=False, capture_output=True, text=True, env=environment)

    def outputs(self) -> dict[str, str]:
        entries = {}
        for line in self.github_output.read_text(encoding="utf-8").splitlines():
            key, _, value = line.partition("=")
            entries[key] = value
        return entries

    def test_packages_the_dsym_when_every_shipped_slice_matches(self) -> None:
        result = self.run_script()

        self.assertEqual(result.returncode, 0, result.stderr)
        zip_path = Path(self.outputs()["dsym_path"])
        # `--keepParent` keeps the bundle name, so an extracted asset is a dSYM `atos -o` accepts.
        names = zipfile.ZipFile(zip_path).namelist()
        self.assertIn("Caffeinate.app.dSYM/Contents/Resources/DWARF/Caffeinate", names)

    def test_rejects_a_dsym_from_a_different_build(self) -> None:
        shutil.copy(OTHER_BUILD_BINARY, self.app_binary)

        result = self.run_script()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is missing from", result.stderr)
        self.assertFalse(self.release_path.exists())

    def test_rejects_a_build_without_a_dsym(self) -> None:
        shutil.rmtree(self.app_dsym)

        result = self.run_script()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("has no dSYM", result.stderr)

    def test_rejects_an_unreadable_binary_rather_than_passing_vacuously(self) -> None:
        # An empty UUID list would walk the slice comparison zero times and call that a pass.
        self.app_binary.write_text("not a Mach-O\n", encoding="utf-8")

        result = self.run_script()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no UUIDs", result.stderr)
        self.assertFalse(self.release_path.exists())


if __name__ == "__main__":
    unittest.main()
