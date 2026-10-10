#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh release
app_dir="$PWD/dist/OpenLaunchpad.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")"
architecture="$(lipo -archs "$app_dir/Contents/MacOS/OpenLaunchpad")"
case "$architecture" in
    arm64) platform="macOS-arm64" ;;
    x86_64) platform="macOS-x86_64" ;;
    *) platform="macOS-universal" ;;
esac
release_dir="$PWD/dist/releases"
name="OpenLaunchpad-${version}-${platform}"
mkdir -p "$release_dir"
codesign --verify --deep --strict "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$release_dir/$name.zip"

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/openlaunchpad-release.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
ditto "$app_dir" "$staging_dir/OpenLaunchpad.app"
ln -s /Applications "$staging_dir/Applications"
cp LICENSE "$staging_dir/LICENSE.txt"
cat > "$staging_dir/Read Me.txt" <<EOF
OpenLaunchpad $version

Drag OpenLaunchpad into Applications.
Requires macOS 26 or later. Architecture: $architecture.

This public preview is ad-hoc signed and not notarized. macOS may block
its first launch. After attempting to open the app, you can choose
System Settings > Privacy & Security > Open Anyway.

Source, changelog, and known limitations:
https://github.com/aadityaraaz/OpenLaunchpad

The MIT license covers OpenLaunchpad code. Apple and third-party artwork
retains its respective ownership.
EOF
hdiutil create -volname "OpenLaunchpad $version" -srcfolder "$staging_dir" -format UDZO -fs HFS+ -ov "$release_dir/$name.dmg"
(cd "$release_dir" && shasum -a 256 "$name.zip" "$name.dmg" > SHA256SUMS.txt)
printf 'Release assets: %s\n' "$release_dir"
