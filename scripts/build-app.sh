#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app_dir="$PWD/dist/OpenLaunchpad.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/OpenLaunchpad" "$app_dir/Contents/MacOS/OpenLaunchpad"
cp scripts/Info.plist "$app_dir/Contents/Info.plist"
swift scripts/make-icon.swift "$app_dir/Contents/Resources"
system_icon="/System/Applications/Apps.app/Contents/Resources/AppIcon.icns"
if [[ -f "$system_icon" ]]; then
    cp "$system_icon" "$app_dir/Contents/Resources/AppIcon.icns"
fi
system_assets="/System/Applications/Apps.app/Contents/Resources/Assets.car"
if [[ -f "$system_assets" ]]; then
    cp "$system_assets" "$app_dir/Contents/Resources/Assets.car"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconName string AppIcon' "$app_dir/Contents/Info.plist"
else
    rm -f "$app_dir/Contents/Resources/Assets.car"
fi
codesign --force --deep --sign - "$app_dir"
printf 'Built %s\n' "$app_dir"
