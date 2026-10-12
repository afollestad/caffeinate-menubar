#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is required. Install it from https://brew.sh/ and rerun this script." >&2
  exit 1
fi

for formula in swiftlint xcsift; do
  if brew list --formula "$formula" >/dev/null 2>&1; then
    echo "$formula already installed"
  else
    brew install "$formula"
  fi
done

if [ "${CI:-false}" = true ]; then
  echo "Skipping Git hook installation in CI."
elif ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "warning: not a Git repository; skipping hook installation." >&2
else
  chmod +x .githooks/*
  git config core.hooksPath .githooks
  echo "Installed Git hooks from .githooks"
fi

echo "Setup complete. Build with ./scripts/build.sh, run with ./scripts/run.sh, test with ./scripts/test.sh, lint with ./scripts/lint.sh."
