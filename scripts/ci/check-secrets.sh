#!/bin/bash
set -euo pipefail

: "${MODE:?}"

required=(APPLE_TEAM_ID MACOS_CERTIFICATE_P12_BASE64 MACOS_CERTIFICATE_PASSWORD MACOS_KEYCHAIN_PASSWORD)
# Canaries skip notarization, so only the other modes need the App Store Connect key.
if [ "$MODE" != canary ]; then
  required+=(APP_STORE_CONNECT_API_KEY_P8_BASE64 APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID)
fi

missing=()
for name in "${required[@]}"; do
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  fi
done

# Checked up front so a missing secret fails in seconds with every gap named, not one at a time mid-build.
if [ ${#missing[@]} -gt 0 ]; then
  echo "::error title=Missing secrets::Set these repository secrets for ${MODE} builds (see RELEASING.md, Secrets): ${missing[*]}"
  exit 1
fi
echo "All ${#required[@]} secrets required for ${MODE} builds are set"
