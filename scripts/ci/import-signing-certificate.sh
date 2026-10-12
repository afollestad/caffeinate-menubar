#!/bin/bash
set -euo pipefail

: "${MACOS_CERTIFICATE_P12_BASE64:?}" "${MACOS_CERTIFICATE_PASSWORD:?}" "${MACOS_KEYCHAIN_PASSWORD:?}" "${KEYCHAIN_PATH:?}"

# No export password ends in a line break, but a secret pasted with one would fail the import.
certificate_password=$MACOS_CERTIFICATE_PASSWORD
while [[ $certificate_password == *$'\n' || $certificate_password == *$'\r' ]]; do
  certificate_password=${certificate_password%?}
done

certificate_path="$RUNNER_TEMP/developer-id-application.p12"
trap 'rm -f "$certificate_path"' EXIT
printf '%s' "$MACOS_CERTIFICATE_P12_BASE64" | base64 --decode > "$certificate_path"

security create-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
if ! security import "$certificate_path" \
  -k "$KEYCHAIN_PATH" \
  -P "$certificate_password" \
  -T /usr/bin/codesign; then
  echo "::error title=Certificate import failed::MACOS_CERTIFICATE_PASSWORD must match MACOS_CERTIFICATE_P12_BASE64, whose .p12 must use the legacy encryption security export writes (not OpenSSL 3+'s default). Reset both with scripts/set-certificate-secrets.sh, which verifies them first."
  exit 1
fi
security list-keychains -d user -s "$KEYCHAIN_PATH"
security default-keychain -s "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$MACOS_KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH" >/dev/null
