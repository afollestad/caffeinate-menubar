#!/bin/bash
set -euo pipefail

: "${EXPORT_PATH:?}" "${RELEASE_PATH:?}" "${APP_NAME:?}" "${GITHUB_OUTPUT:?}"

# Release builds ship a stripped binary, so a crash report symbolicates only against this dSYM, and
# nothing else keeps it once the runner is discarded. Package it for every mode that hands out a binary.
app_dsym="$EXPORT_PATH/${APP_NAME}.app.dSYM"
app_binary="$EXPORT_PATH/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

if [ ! -d "$app_dsym" ]; then
  echo "error: build has no dSYM for ${APP_NAME}.app: $app_dsym" >&2
  exit 1
fi

# Crash reports match a dSYM by UUID alone, so a dSYM from another build reads as "no symbols" months
# later. `|| true` turns an unreadable file into an empty list, rejected below rather than passing
# vacuously.
dsym_uuids=$(dwarfdump --uuid "$app_dsym" 2>/dev/null | awk '{print $2}' | tr '\n' ' ') || true
app_uuids=$(dwarfdump --uuid "$app_binary" 2>/dev/null | awk '{print $2}' | tr '\n' ' ') || true
if [ -z "${app_uuids// /}" ] || [ -z "${dsym_uuids// /}" ]; then
  echo "error: no UUIDs read for ${APP_NAME} (app: '${app_uuids}', dSYM: '${dsym_uuids}')" >&2
  echo "hint: expected a Mach-O at $app_binary and DWARF inside $app_dsym" >&2
  exit 1
fi

for uuid in $app_uuids; do
  case " $dsym_uuids " in
    *" $uuid "*) ;;
    *)
      echo "error: shipped ${APP_NAME} slice $uuid is missing from $app_dsym" >&2
      echo "app:  $app_uuids" >&2
      echo "dSYM: $dsym_uuids" >&2
      exit 1
      ;;
  esac
done
echo "dSYM covers every shipped slice: $app_uuids"

mkdir -p "$RELEASE_PATH"
dsym_path="$RELEASE_PATH/${APP_NAME}.dSYMs.zip"
ditto -c -k --keepParent "$app_dsym" "$dsym_path"
echo "dsym_path=$dsym_path" >> "$GITHUB_OUTPUT"
