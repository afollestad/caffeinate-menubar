#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: swiftlint is required. Run ./scripts/setup.sh or install it with Homebrew." >&2
  exit 1
fi

# Run from the repo root without --config so the nested Tests/.swiftlint.yml applies.
swiftlint lint --strict --quiet "$@"
