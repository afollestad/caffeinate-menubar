#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import subprocess

SEMVER_TAG_PATTERN = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")


def git(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *arguments], check=check, capture_output=True, text=True)


def parse_version(tag: str) -> tuple[int, ...]:
    match = SEMVER_TAG_PATTERN.fullmatch(tag)
    if not match:
        raise SystemExit(f"error: release tag must be vX.Y.Z, got {tag!r}")
    return tuple(int(component) for component in match.groups())


def resolve_previous_tag(current_tag: str) -> str | None:
    current_version = parse_version(current_tag)
    candidates = []
    for tag in git("tag", "--list").stdout.splitlines():
        if SEMVER_TAG_PATTERN.fullmatch(tag) and parse_version(tag) < current_version:
            candidates.append((parse_version(tag), tag))
    return max(candidates)[1] if candidates else None


def resolve_notes_base(previous_tag: str) -> str:
    if git("merge-base", "--is-ancestor", previous_tag, "HEAD", check=False).returncode == 0:
        return previous_tag

    # A rewritten history can orphan the tag; its release commit still marks where the notes start.
    expected_subject = f"Release Caffeinate {previous_tag}"
    for line in git("log", "--first-parent", "--format=%H%x09%s", "HEAD").stdout.splitlines():
        commit, separator, subject = line.partition("\t")
        if separator and subject == expected_subject:
            return commit

    raise SystemExit(
        f"error: {previous_tag} is not an ancestor of HEAD and no current-history "
        f"{expected_subject!r} commit exists"
    )


current_tag = os.environ.get("TAG_NAME", "")
previous_tag = resolve_previous_tag(current_tag)
# The first release has no earlier tag; empty outputs tell the notes step to cover the whole history.
notes_base = resolve_notes_base(previous_tag) if previous_tag else ""

with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
    print(f"tag={previous_tag or ''}", file=output)
    print(f"notes_base={notes_base}", file=output)

if previous_tag:
    print(f"Resolved previous release tag {previous_tag} with notes base {notes_base}")
else:
    print(f"No release precedes {current_tag}; notes cover the full history")
