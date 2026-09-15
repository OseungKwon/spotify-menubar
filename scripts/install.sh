#!/usr/bin/env bash
# 빌드한 앱을 Applications로 옮기고 실행한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SpotifyMenuBar"
SRC="$ROOT/build/$APP_NAME.app"
DEST_DIR="${INSTALL_DIR:-/Applications}"

[ -d "$SRC" ] || { echo "먼저 scripts/build.sh 를 실행하세요." >&2; exit 1; }
if [ ! -w "$DEST_DIR" ]; then
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
fi

# 실행 중인 예전 버전이 있으면 교체 전에 내린다.
pkill -f "$DEST_DIR/$APP_NAME.app" 2>/dev/null || true
rm -rf "${DEST_DIR:?}/$APP_NAME.app"
cp -R "$SRC" "$DEST_DIR/"
open "$DEST_DIR/$APP_NAME.app"

echo "installed: $DEST_DIR/$APP_NAME.app"
