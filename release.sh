#!/bin/zsh
# Builds a release and publishes it to GitHub Releases, where Sparkle picks it up.
#
#   ./release.sh 0.2 "What changed in this version"
#
# Environment:
#   PUBLISH=0            build into build/release without bumping git or uploading (for testing)
#   DOWNLOAD_BASE_URL    where the update archive will live (default: the GitHub release)
set -euo pipefail
cd "$(dirname "$0")"
source ./release.env

VERSION=${1:?usage: ./release.sh <version> [release notes]}
NOTES=${2:-}
PUBLISH=${PUBLISH:-1}
TAG="v$VERSION"
SPARKLE_BIN=vendor/sparkle-2.10.0/bin
OUT=build/release
DOWNLOAD_BASE_URL=${DOWNLOAD_BASE_URL:-https://github.com/$REPO/releases/download/$TAG/}

if [[ $PUBLISH == 1 ]]; then
  [[ -z $(git status --porcelain) ]] || { echo "Commit or stash your changes first."; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "GitHub CLI isn't logged in: run 'gh auth login'."; exit 1; }
fi

# Sparkle compares CFBundleVersion, so it has to go up with every release. The versions live in
# project.yml, shared by the app and its widget extension.
BUILD=$(( $(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\([0-9]*\)"/\1/p' project.yml) + 1 ))
sed -i '' -e "s/^\( *MARKETING_VERSION: \)\".*\"/\1\"$VERSION\"/" \
          -e "s/^\( *CURRENT_PROJECT_VERSION: \)\".*\"/\1\"$BUILD\"/" project.yml
echo "Building Bilby $VERSION ($BUILD)"

./make-dmg.sh

rm -rf "$OUT" && mkdir -p "$OUT/updates"
ARCHIVE="Bilby-$VERSION.zip"
ditto -c -k --keepParent build/Bilby.app "$OUT/updates/$ARCHIVE"
cp build/Bilby.dmg "$OUT/Bilby.dmg"
if [[ -n $NOTES ]]; then
  print -r -- "<p>${NOTES}</p>" > "$OUT/updates/Bilby-$VERSION.html"
fi

# Signs the archive with the key in the Keychain and writes the feed.
"$SPARKLE_BIN/generate_appcast" --account bilby --embed-release-notes \
  --download-url-prefix "$DOWNLOAD_BASE_URL" -o "$OUT/appcast.xml" "$OUT/updates"

if [[ $PUBLISH != 1 ]]; then
  echo "Built $OUT (not published)"
  exit 0
fi

git commit -q -am "Release $VERSION"
git tag "$TAG"
git push -q && git push -q origin "$TAG"
gh release create "$TAG" --repo "$REPO" --title "Bilby $VERSION" --notes "${NOTES:-Bilby $VERSION}" \
  "$OUT/updates/$ARCHIVE" "$OUT/Bilby.dmg" "$OUT/appcast.xml"
echo "Published Bilby $VERSION"
