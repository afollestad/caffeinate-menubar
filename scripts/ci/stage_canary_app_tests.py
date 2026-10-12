#!/usr/bin/env python3
from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT_PATH = Path(__file__).with_name("stage-canary-app.sh")


class StageCanaryAppTests(unittest.TestCase):
    """`actions/upload-artifact` replaces a symlink with a copy of its target and roots its archive at
    the uploaded path, both silently, so an unstaged upload arrives with an invalid signature or as a
    bare `Contents/` folder."""

    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        root = Path(self.temporary_directory.name)
        self.export_path = root / "export"
        self.release_path = root / "release"
        self.output_path = root / "github-output"
        self.bundle = self.export_path / "Caffeinate.app"
        (self.bundle / "Contents" / "MacOS").mkdir(parents=True)
        (self.bundle / "Contents" / "Info.plist").write_text("plist\n", encoding="utf-8")
        executable = self.bundle / "Contents" / "MacOS" / "Caffeinate"
        executable.write_text("binary\n", encoding="utf-8")
        executable.chmod(0o755)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def run_script(self) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment.update(
            EXPORT_PATH=str(self.export_path),
            RELEASE_PATH=str(self.release_path),
            GITHUB_OUTPUT=str(self.output_path),
            APP_NAME="Caffeinate",
        )
        return subprocess.run([str(SCRIPT_PATH)], check=False, capture_output=True, text=True, env=environment)

    def staged_path(self) -> Path:
        """The staging directory is named freshly on every run, so the script's `app_dir` output is
        the only record of the upload path."""
        outputs = dict(line.split("=", 1) for line in self.output_path.read_text(encoding="utf-8").splitlines())
        return Path(outputs["app_dir"])

    def test_stages_the_bundle_as_the_only_entry_at_the_staging_root(self) -> None:
        result = self.run_script()

        self.assertEqual(result.returncode, 0, result.stderr)
        stage_path = self.staged_path()
        self.assertEqual([entry.name for entry in stage_path.iterdir()], ["Caffeinate.app"])
        self.assertTrue(str(stage_path).startswith(str(self.release_path)))
        staged_executable = stage_path / "Caffeinate.app" / "Contents" / "MacOS" / "Caffeinate"
        self.assertTrue(staged_executable.stat().st_mode & stat.S_IXUSR)

    def test_rejects_a_symlink_nested_in_the_bundle(self) -> None:
        (self.bundle / "Contents" / "Frameworks").symlink_to("MacOS")

        result = self.run_script()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("flatten symlinks", result.stderr)
        self.assertIn("Frameworks", result.stderr)
        self.assertFalse(self.output_path.exists())

    def test_fails_when_the_bundle_is_missing(self) -> None:
        self.bundle.rename(self.export_path / "Other.app")

        result = self.run_script()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no app bundle", result.stderr)

    def test_excludes_what_earlier_steps_left_in_the_release_path(self) -> None:
        self.release_path.mkdir(parents=True)
        (self.release_path / "Caffeinate.dSYMs.zip").write_text("zip\n", encoding="utf-8")

        result = self.run_script()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([entry.name for entry in self.staged_path().iterdir()], ["Caffeinate.app"])


if __name__ == "__main__":
    unittest.main()
