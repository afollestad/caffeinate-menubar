#!/bin/bash
set -euo pipefail

: "${EXPORT_PATH:?}" "${APP_NAME:?}" "${VERSION:?}" "${BUILD:?}" "${APPLE_TEAM_ID:?}"

app_path="$EXPORT_PATH/${APP_NAME}.app"
info_plist="$app_path/Contents/Info.plist"

actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")
actual_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")
if [ "$actual_version" != "$VERSION" ] || [ "$actual_build" != "$BUILD" ]; then
  echo "error: app has version ${actual_version} (${actual_build}), expected ${VERSION} (${BUILD})" >&2
  exit 1
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$info_plist" 2>/dev/null || true)" != true ]; then
  echo "error: app is missing LSUIElement, so it would show a Dock icon" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$app_path"
signature=$(codesign --display --verbose=2 "$app_path" 2>&1)
if ! grep -q '^Authority=Developer ID Application:' <<< "$signature"; then
  echo "error: app is not signed with a Developer ID Application certificate" >&2
  exit 1
fi
if ! grep -qx "TeamIdentifier=${APPLE_TEAM_ID}" <<< "$signature"; then
  echo "error: app is not signed by team ${APPLE_TEAM_ID}" >&2
  exit 1
fi
# Notarization rejects binaries without the hardened runtime.
if ! grep -Eq '^CodeDirectory .*flags=0x[0-9a-f]+\([^)]*runtime' <<< "$signature"; then
  echo "error: app is not signed with the hardened runtime" >&2
  exit 1
fi

executable_path="$app_path/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_plist")"
architectures=$(lipo -archs "$executable_path")
for required_architecture in arm64 x86_64; do
  case " $architectures " in
    *" $required_architecture "*) ;;
    *)
      echo "error: app executable is missing the $required_architecture slice (found: $architectures)" >&2
      exit 1
      ;;
  esac
done

echo "Verified ${APP_NAME} ${VERSION} (${BUILD}): Developer ID signed, hardened runtime, ${architectures}"
