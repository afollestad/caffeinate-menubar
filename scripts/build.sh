#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

configuration=debug
for arg in "$@"; do
  case "$arg" in
    --release) configuration=release ;;
    *)
      echo "usage: $0 [--release]" >&2
      exit 1
      ;;
  esac
done

swift_filtered build -c "$configuration" --product "$app_name"
bin_path=$(swift build -c "$configuration" --show-bin-path)

app=$(app_path "$configuration")
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_path/$app_name" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"

# SwiftPM can't compile asset catalogs or Icon Composer documents, so actool builds Assets.car and AppIcon.icns.
partial_plist=$(mktemp -t caffeinate-actool)
trap 'rm -f "$partial_plist"' EXIT
if ! actool_output=$(xcrun actool Resources/Assets.xcassets Resources/AppIcon.icon \
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

codesign --force --sign - "$app"
echo "Built $app"
