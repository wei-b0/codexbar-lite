#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 <version> <build-number>"
  exit 1
fi

VERSION="$1"
BUILD_NUMBER="$2"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CodexBarLite"
ARCHIVE_NAME="$APP_NAME-macos-v$VERSION.zip"
UPDATES_DIR="$ROOT_DIR/dist/updates"
SPARKLE_TOOLS="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"

cd "$ROOT_DIR"
BUILD_ONLY=1 APP_VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" ./scripts/install.sh

rm -rf "$UPDATES_DIR"
mkdir -p "$UPDATES_DIR"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/dist/$APP_NAME.app" "$UPDATES_DIR/$ARCHIVE_NAME"

"$SPARKLE_TOOLS/generate_appcast" \
  --download-url-prefix "https://github.com/wei-b0/codexbar-lite/releases/download/v$VERSION/" \
  "$UPDATES_DIR"

cp "$UPDATES_DIR/appcast.xml" "$ROOT_DIR/appcast.xml"
cp "$UPDATES_DIR/$ARCHIVE_NAME" "$ROOT_DIR/dist/$ARCHIVE_NAME"

echo "Built dist/$ARCHIVE_NAME and appcast.xml"
