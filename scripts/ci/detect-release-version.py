#!/usr/bin/env python3
from __future__ import annotations

import os
import plistlib
import re
import subprocess

INFO_PLIST = "Resources/Info.plist"
VERSION_KEY = "CFBundleShortVersionString"
BUILD_KEY = "CFBundleVersion"
SEMVER_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")


def parse_versions(data: bytes) -> tuple[str | None, str | None]:
    try:
        plist = plistlib.loads(data)
    except Exception:
        return None, None
    version = plist.get(VERSION_KEY)
    build = plist.get(BUILD_KEY)
    return (
        str(version).strip() if version is not None else None,
        str(build).strip() if build is not None else None,
    )


def read_versions_at(ref: str) -> tuple[str | None, str | None]:
    if not ref or set(ref) == {"0"}:
        return None, None
    result = subprocess.run(["git", "show", f"{ref}:{INFO_PLIST}"], check=False, capture_output=True)
    return parse_versions(result.stdout) if result.returncode == 0 else (None, None)


def release_tag_exists(tag: str) -> bool:
    result = subprocess.run(
        ["git", "ls-remote", "--exit-code", "--tags", "origin", f"refs/tags/{tag}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode == 0:
        return True
    if result.returncode == 2:
        return False
    raise SystemExit(f"error: failed to check release tag {tag}")


with open(INFO_PLIST, "rb") as file:
    version, build = parse_versions(file.read())
if version is None:
    raise SystemExit(f"error: {INFO_PLIST} is missing {VERSION_KEY}")
if build is None:
    raise SystemExit(f"error: {INFO_PLIST} is missing {BUILD_KEY}")

previous_version, previous_build = read_versions_at(os.environ.get("BEFORE_SHA", ""))
is_dry_run = os.environ.get("IS_DRY_RUN", "").lower() == "true"
tag = f"v{version}"

# Manual runs are always dry runs, so workflow_dispatch can never reach the tag or release steps.
# Push-triggered releases require a readable previous version: the push that creates `main` (whose
# `before` is all zeros) builds a canary, and a later push publishes the current version if its tag
# is still missing, which also covers retrying a failed release.
version_changed = previous_version is not None and previous_version != version
has_release_tag = False if is_dry_run else release_tag_exists(tag)
if not is_dry_run and version_changed and has_release_tag:
    raise SystemExit(f"error: release tag {tag} already exists")

should_release = not is_dry_run and previous_version is not None and not has_release_tag
# Every run builds. A push that cannot publish still produces a signed canary artifact, skipping
# notarization because a notarytool round trip on every merge outweighs Gatekeeper acceptance for a
# build that never ships.
mode = "dry-run" if is_dry_run else "release" if should_release else "canary"

# Validate unconditionally, so a malformed value fails the push that introduced it.
if not SEMVER_PATTERN.fullmatch(version):
    raise SystemExit(f"error: version must be X.Y.Z, got {version!r}")
if not build.isdigit():
    raise SystemExit(f"error: build number must be an integer, got {build!r}")
if should_release and version_changed and previous_build and previous_build.isdigit() and int(build) <= int(previous_build):
    raise SystemExit(f"error: build number must increase from {previous_build} to a larger integer, got {build}")

# Releases attach their ZIP and dSYMs to the GitHub Release; every other mode uploads artifacts
# named after the run, so a download says which commit it came from.
short_sha = os.environ.get("GITHUB_SHA", "")[:7]
artifact_name = "" if mode == "release" else f"Caffeinate-{mode}-{version}-{build}-{short_sha}"
dsym_artifact_name = f"{artifact_name}-dSYMs" if artifact_name else ""

with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
    print(f"mode={mode}", file=output)
    print(f"version={version}", file=output)
    print(f"build={build}", file=output)
    print(f"tag={tag}", file=output)
    print(f"artifact_name={artifact_name}", file=output)
    print(f"dsym_artifact_name={dsym_artifact_name}", file=output)

descriptions = {"dry-run": "dry run", "release": "release", "canary": "canary build"}
print(f"Preparing {descriptions[mode]} for v{version} (build {build})")
