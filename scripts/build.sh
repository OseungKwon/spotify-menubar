#!/usr/bin/env bash
# .app 번들을 만든다. SwiftPM은 실행 파일만 내놓기 때문에 번들은 직접 조립한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SpotifyMenuBar"
APP="$ROOT/build/$APP_NAME.app"

cd "$ROOT"
swift build -c release --disable-sandbox

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# 서명이 없으면 macOS가 자동화 권한을 기억하지 못한다. 배포용이 아니므로 ad-hoc으로 충분하다.
codesign --force --sign - "$APP" >/dev/null

echo "built: $APP"
