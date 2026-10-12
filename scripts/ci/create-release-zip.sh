#!/bin/bash
set -euo pipefail

: "${EXPORT_PATH:?}" "${RELEASE_PATH:?}" "${APP_NAME:?}" "${GITHUB_OUTPUT:?}"

mkdir -p "$RELEASE_PATH"
zip_path="$RELEASE_PATH/${APP_NAME}.app.zip"
ditto -c -k --keepParent "$EXPORT_PATH/${APP_NAME}.app" "$zip_path"
echo "zip_path=$zip_path" >> "$GITHUB_OUTPUT"
