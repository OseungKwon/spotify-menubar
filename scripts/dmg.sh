#!/usr/bin/env bash
# 배포용 .dmg를 만든다. 내려받아 Applications로 끌어다 놓는 맥의 보통 방식.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SpotifyMenuBar"
APP="$ROOT/build/$APP_NAME.app"

"$ROOT/scripts/build.sh" >/dev/null

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$ROOT/build/$APP_NAME-$VERSION.dmg"

# 창을 열었을 때 앱과 Applications가 나란히 보이도록 둘만 담는다.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -format UDZO \
    -quiet \
    "$DMG"

echo "built: $DMG ($(du -h "$DMG" | cut -f1))"
