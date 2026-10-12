#!/bin/bash
set -euo pipefail
# common.sh changes to the repo root, so remember where a relative .p12 path started.
invocation_dir=$PWD
source "$(dirname "$0")/lib/common.sh"

# Stores the Developer ID Application identity as the MACOS_CERTIFICATE_* secrets CI signs with.
#
# The identity is re-exported through a throwaway keychain, which keeps only that identity (no other
# private key reaches CI) and writes the legacy PKCS#12 encryption `security export` produces: CI's
# `security import` rejects OpenSSL 3+'s default .p12 format with "MAC verification failed", even
# with the right password. The export password is random and never displayed, so it cannot be mistyped.
usage="usage: $0 [--dry-run] [identities.p12]  (exports from the login keychain when no .p12 is given)"
dry_run=0
source_p12=
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -*) echo "$usage" >&2; exit 1 ;;
    *)
      case "$arg" in
        /*) ;;
        *) arg="$invocation_dir/$arg" ;;
      esac
      if [ -n "$source_p12" ] || [ ! -f "$arg" ]; then
        echo "$usage" >&2
        exit 1
      fi
      source_p12=$arg
      ;;
  esac
done

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
work_dir=$(mktemp -d)
staging="$work_dir/staging.keychain-db"
verify="$work_dir/verify.keychain-db"
# `security export` reports "bytes written" on stderr; show its output only when it fails.
export_identities() {
  if ! security export -t identities -f pkcs12 "$@" >"$work_dir/export.log" 2>&1; then
    cat "$work_dir/export.log" >&2
    exit 1
  fi
}
cleanup() {
  security delete-keychain "$staging" 2>/dev/null || true
  security delete-keychain "$verify" 2>/dev/null || true
  rm -rf "$work_dir"
}
trap cleanup EXIT

if [ -n "$source_p12" ]; then
  read -rsp "Export password for $(basename "$source_p12"): " source_password
  echo
else
  source_p12="$work_dir/login-identities.p12"
  source_password=$(openssl rand -hex 16)
  echo "Exporting identities from the login keychain; approve each macOS prompt with your login password."
  export_identities -k login.keychain-db -P "$source_password" -o "$source_p12"
fi

security create-keychain -p "$(openssl rand -hex 16)" "$staging"
# `-A` lets the export below run without access prompts; the keychain is deleted on exit.
if ! security import "$source_p12" -k "$staging" -P "$source_password" -A >/dev/null; then
  echo "error: could not import $(basename "$source_p12"): wrong password, or OpenSSL 3+'s .p12 format; omit the argument to export from the login keychain" >&2
  exit 1
fi

# Keep only Developer ID Application identities.
security find-identity "$staging" \
  | sed -nE 's/^ *[0-9]+\) ([0-9A-F]{40}) "(.*)".*$/\1 \2/p' \
  | sort -u \
  | while read -r hash name; do
      case "$name" in
        "Developer ID Application: "*) ;;
        *) security delete-identity -Z "$hash" "$staging" >/dev/null ;;
      esac
    done
identities=$(security find-identity "$staging" | sed -nE 's/^ *[0-9]+\) [0-9A-F]{40} "(.*)".*$/\1/p' | sort -u)
if [ -z "$identities" ]; then
  echo "error: no Developer ID Application identity with a private key found" >&2
  exit 1
fi
if [ "$(printf '%s\n' "$identities" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "error: expected one Developer ID Application identity; delete the extra ones and rerun:" >&2
  printf '  %s\n' "$identities" >&2
  exit 1
fi

password=$(openssl rand -hex 16)
p12="$work_dir/developer-id.p12"
export_identities -k "$staging" -P "$password" -o "$p12"

# Import exactly as scripts/ci/import-signing-certificate.sh does, so anything CI would reject fails here.
security create-keychain -p "$(openssl rand -hex 16)" "$verify"
security import "$p12" -k "$verify" -P "$password" -T /usr/bin/codesign >/dev/null
if ! security find-identity -v -p codesigning "$verify" | grep -q '"Developer ID Application: '; then
  echo "error: $identities is not valid for code signing (expired or untrusted)" >&2
  exit 1
fi

if [ "$dry_run" -eq 1 ]; then
  echo "Dry run: $identities is ready for CI; no secrets changed."
  exit 0
fi
base64 -i "$p12" | gh secret set MACOS_CERTIFICATE_P12_BASE64 -R "$repo"
printf '%s' "$password" | gh secret set MACOS_CERTIFICATE_PASSWORD -R "$repo"
echo "Set MACOS_CERTIFICATE_P12_BASE64 and MACOS_CERTIFICATE_PASSWORD on $repo from $identities."
