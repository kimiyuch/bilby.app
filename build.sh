#!/bin/zsh
# Builds Bilby.app for the Mac (arm64, ad-hoc signed) into ./build.
set -euo pipefail
cd "$(dirname "$0")"

source ./release.env
# Where the app looks for updates; override with BILBY_FEED_URL (e.g. for local testing).
FEED_URL=${BILBY_FEED_URL:-https://github.com/$REPO/releases/latest/download/appcast.xml}
XCODEGEN=$(command -v xcodegen || echo /opt/homebrew/bin/xcodegen)

APP=build/Bilby.app

./scripts/fetch-sparkle.sh
"$XCODEGEN" generate --quiet
# -quiet still prints "error: the following command failed with exit code 0…" on success; drop that line.
xcodebuild -project Bilby.xcodeproj -scheme Bilby -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData -quiet build 2>&1 \
  | { grep -v 'failed with exit code 0 but produced no further output' || true; }

rm -rf "$APP"
ditto build/DerivedData/Build/Products/Release/Bilby.app "$APP"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL $FEED_URL" "$APP/Contents/Info.plist"

# Sparkle's license has to ship with the framework.
mkdir -p "$APP/Contents/Resources/Licenses/Sparkle"
cp vendor/sparkle-2.10.0/LICENSE "$APP/Contents/Resources/Licenses/Sparkle/"

# Sign inside-out: Sparkle's helpers, the framework, then the app.
FW="$APP/Contents/Frameworks"
S="$FW/Sparkle.framework/Versions/B"
codesign --force --sign - "$S/XPCServices/Installer.xpc" "$S/XPCServices/Downloader.xpc" "$S/Autoupdate" "$S/Updater.app"
codesign --force --sign - "$FW/Sparkle.framework"
codesign --force --sign - "$APP"
echo "Built $APP"
