#!/usr/bin/env bash
# .app 번들을 만든다. SwiftPM은 실행 파일만 내놓기 때문에 번들은 직접 조립한다.
#
# UNIVERSAL=1을 주면 arm64와 x86_64를 따로 빌드해 lipo로 합친다. 배포본에만
# 쓴다. 평소 빌드까지 두 번 돌리면 개발할 때 기다리는 시간만 늘어난다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SpotifyMenuBar"
APP="$ROOT/build/$APP_NAME.app"
BINARY="$APP/Contents/MacOS/$APP_NAME"

cd "$ROOT"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    # 아키텍처별로 작업 폴더를 나눈다. 한 폴더에서 번갈아 빌드하면
    # SwiftPM이 들고 있던 빌드 상태와 어긋나 "not registered"로 멈춘다.
    slices=()
    for arch in arm64 x86_64; do
        swift build -c release --arch "$arch" --scratch-path ".build/universal-$arch" --disable-sandbox
        slices+=(".build/universal-$arch/$arch-apple-macosx/release/$APP_NAME")
    done
    lipo -create -output "$BINARY" "${slices[@]}"
else
    swift build -c release --disable-sandbox
    cp ".build/release/$APP_NAME" "$BINARY"
fi

# 서명이 없으면 macOS가 자동화 권한을 기억하지 못한다. 배포용이 아니므로 ad-hoc으로 충분하다.
codesign --force --sign - "$APP" >/dev/null

echo "built: $APP ($(lipo -archs "$BINARY"))"
