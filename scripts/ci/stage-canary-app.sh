#!/bin/bash
set -euo pipefail

: "${EXPORT_PATH:?}" "${RELEASE_PATH:?}" "${APP_NAME:?}" "${GITHUB_OUTPUT:?}"

# Canaries upload the bundle itself so a download is a runnable app, not an archive inside an archive.
# `actions/upload-artifact` fails silently in two ways this script guards against:
# - It stores a copy of each symlink's target, which would invalidate the code signature.
# - It roots the archive at the uploaded path and drops that directory's name, so uploading the bundle
#   would store a bare `Contents/`. Staging the app alone in a fresh directory makes the bundle the
#   archive's only top-level entry.
app_path="$EXPORT_PATH/${APP_NAME}.app"
if [ ! -d "$app_path" ]; then
  echo "error: no app bundle at $app_path" >&2
  exit 1
fi

symlinks=$(find "$app_path" -type l)
if [ -n "$symlinks" ]; then
  echo "error: canary uploads flatten symlinks, but ${APP_NAME}.app contains:" >&2
  echo "$symlinks" >&2
  echo "hint: ZIP the bundle for canaries too, or stop embedding the linked payload." >&2
  exit 1
fi

# A fresh directory, so nothing earlier steps wrote under RELEASE_PATH (such as the dSYM ZIP) becomes a
# second top-level entry. Copied rather than moved so EXPORT_PATH stays intact.
mkdir -p "$RELEASE_PATH"
stage_path=$(mktemp -d "$RELEASE_PATH/canary.XXXXXX")
ditto "$app_path" "$stage_path/${APP_NAME}.app"
echo "app_dir=$stage_path" >> "$GITHUB_OUTPUT"
echo "Staged ${APP_NAME}.app at $stage_path for upload"
