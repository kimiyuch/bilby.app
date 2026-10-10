#!/bin/zsh
# Builds Bilby.app and packages it as build/Bilby.dmg (drag-to-Applications installer).
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

STAGING=build/dmg
DMG=build/Bilby.dmg
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/Bilby.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname Bilby -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"
echo "Built $DMG"
