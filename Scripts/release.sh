#!/bin/bash
# Сборка релиза: ад-хок подпись, zip, подпись Sparkle.
# Использование: Scripts/release.sh 0.1.0
set -euo pipefail
VERSION="${1:?usage: Scripts/release.sh <version>}"

xcodegen generate
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -configuration Release \
  -derivedDataPath build clean build

APP="build/Build/Products/Release/Aeolus.app"
codesign --force --deep -s - "$APP"

mkdir -p dist
ZIP="dist/Aeolus-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SIGN_UPDATE="$(find build/SourcePackages -name sign_update -type f -perm +111 | head -1)"
echo "--- Sparkle signature for appcast.xml:"
"$SIGN_UPDATE" "$ZIP"
echo "--- sha256 for Homebrew cask:"
shasum -a 256 "$ZIP"
echo "Done: $ZIP"
