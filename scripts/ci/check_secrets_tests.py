#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

SCRIPT_PATH = Path(__file__).with_name("check-secrets.sh")
SIGNING_SECRETS = ["APPLE_TEAM_ID", "MACOS_CERTIFICATE_P12_BASE64", "MACOS_CERTIFICATE_PASSWORD", "MACOS_KEYCHAIN_PASSWORD"]
NOTARY_SECRETS = ["APP_STORE_CONNECT_API_KEY_P8_BASE64", "APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID"]


class CheckSecretsTests(unittest.TestCase):
    def run_script(self, mode: str, secrets: dict[str, str]) -> subprocess.CompletedProcess[str]:
        environment = {key: value for key, value in os.environ.items() if key not in SIGNING_SECRETS + NOTARY_SECRETS}
        environment["MODE"] = mode
        # GitHub passes an unset secret as an empty string, not an absent variable.
        environment.update({name: "" for name in SIGNING_SECRETS + NOTARY_SECRETS})
        environment.update(secrets)
        return subprocess.run([str(SCRIPT_PATH)], check=False, capture_output=True, text=True, env=environment)

    def test_names_every_missing_secret_at_once(self) -> None:
        result = self.run_script("release", {"APPLE_TEAM_ID": "TEAM123456"})

        self.assertNotEqual(result.returncode, 0)
        for name in SIGNING_SECRETS[1:] + NOTARY_SECRETS:
            self.assertIn(name, result.stdout)
        self.assertNotIn("APPLE_TEAM_ID", result.stdout.split("Secrets):", 1)[1])

    def test_canaries_do_not_need_the_notarization_key(self) -> None:
        result = self.run_script("canary", {name: "value" for name in SIGNING_SECRETS})

        self.assertEqual(result.returncode, 0, result.stdout)

    def test_dry_runs_need_the_notarization_key(self) -> None:
        result = self.run_script("dry-run", {name: "value" for name in SIGNING_SECRETS})

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("APP_STORE_CONNECT_KEY_ID", result.stdout)

    def test_never_prints_secret_values(self) -> None:
        secrets = {name: f"secret-value-{index}" for index, name in enumerate(SIGNING_SECRETS + NOTARY_SECRETS[:1])}

        result = self.run_script("release", secrets)

        self.assertNotEqual(result.returncode, 0)
        for value in secrets.values():
            self.assertNotIn(value, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
