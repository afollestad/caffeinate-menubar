#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

: "${EXPORT_PATH:?}"

# The imported keychain holds a single Developer ID Application identity, so the name prefix is unambiguous.
CODESIGN_IDENTITY="Developer ID Application" "$repo_root/scripts/build.sh" --release

# Later steps read the bundle and its dSYM from EXPORT_PATH, outside the checkout, so `.build/` layout stays private.
app=$(app_path release)
mkdir -p "$EXPORT_PATH"
ditto "$app" "$EXPORT_PATH/$app_name.app"
ditto "$app.dSYM" "$EXPORT_PATH/$app_name.app.dSYM"
