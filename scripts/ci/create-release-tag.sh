#!/bin/bash
set -euo pipefail

: "${TAG_NAME:?}" "${VERSION:?}"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git tag -a "$TAG_NAME" -m "Release Caffeinate ${VERSION}"
git push origin "$TAG_NAME"
