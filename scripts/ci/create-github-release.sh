#!/bin/bash
set -euo pipefail

: "${TAG_NAME:?}" "${ZIP_PATH:?}" "${DSYM_PATH:?}" "${RELEASE_NOTES_PATH:?}" "${APP_NAME:?}" "${GITHUB_REPOSITORY:?}"

if [ ! -s "$RELEASE_NOTES_PATH" ]; then
  echo "error: release notes file is missing or empty: $RELEASE_NOTES_PATH" >&2
  exit 1
fi

# The app ships stripped, so the dSYMs ride along as a second asset: crash reports from this build
# symbolicate against nothing else.
gh release create "$TAG_NAME" \
  "$ZIP_PATH#${APP_NAME}.app.zip" \
  "$DSYM_PATH#${APP_NAME}.dSYMs.zip" \
  --repo "$GITHUB_REPOSITORY" \
  --title "$TAG_NAME" \
  --notes-file "$RELEASE_NOTES_PATH"
