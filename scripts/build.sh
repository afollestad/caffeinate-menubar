#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

# Signs ad hoc by default; set CODESIGN_IDENTITY (e.g. "Developer ID Application") to sign for distribution.
configuration=debug
build_flags=()
for arg in "$@"; do
  case "$arg" in
    --release)
      configuration=release
      # Releases ship one universal binary for Apple silicon and Intel Macs.
      build_flags=(--arch arm64 --arch x86_64)
      ;;
    *)
      echo "usage: $0 [--release]" >&2
      exit 1
      ;;
  esac
done

# The `+` guard keeps macOS's bash 3.2 from treating an empty array as unbound under `set -u`.
swift_filtered build -c "$configuration" ${build_flags[@]+"${build_flags[@]}"} --product "$app_name"
bin_path=$(swift build -c "$configuration" ${build_flags[@]+"${build_flags[@]}"} --show-bin-path)

app=$(app_path "$configuration")
dsym="$app.dSYM"
rm -rf "$app" "$dsym"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_path/$app_name" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"

# SwiftPM can't compile asset catalogs or Icon Composer documents, so actool builds Assets.car and AppIcon.icns.
# Pass absolute paths: actool runs in a shared daemon that resolves relative ones against its own working directory.
partial_plist=$(mktemp -t caffeinate-actool)
trap 'rm -f "$partial_plist"' EXIT
if ! actool_output=$(xcrun actool "$repo_root/Resources/Assets.xcassets" "$repo_root/Resources/AppIcon.icon" \
  --compile "$app/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 26.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$partial_plist" \
  --output-format human-readable-text \
  --errors --warnings 2>&1); then
  echo "$actool_output" >&2
  exit 1
fi
# Show diagnostics, but not the list of compiled files.
echo "$actool_output" | awk '/^\/\* com.apple.actool.compilation-results \*\//{skip=1; next} /^\/\* /{skip=0} !skip && NF'
# actool exits 0 when `--app-icon` matches nothing, leaving the app without an icon.
if [ ! -f "$app/Contents/Resources/AppIcon.icns" ]; then
  echo "error: actool did not produce AppIcon.icns; check Resources/AppIcon.icon" >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c "Merge $partial_plist" "$app/Contents/Info.plist" >/dev/null

if [ "$configuration" = release ]; then
  # Ship a stripped binary; the dSYM beside the bundle symbolicates its crash reports.
  ditto "$bin_path/$app_name.dSYM" "$dsym"
  strip -rSTx "$app/Contents/MacOS/$app_name"
fi

identity=${CODESIGN_IDENTITY:--}
if [ "$identity" = - ]; then
  codesign --force --sign - "$app"
else
  # Notarization requires the hardened runtime and a secure timestamp.
  codesign --force --options runtime --timestamp --sign "$identity" "$app"
fi
echo "Built $app"
