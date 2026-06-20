#!/bin/bash
set -e

PROJECT="MonitorBarApp.xcodeproj"
SCHEME="MonitorBarApp"
ARCHIVE_PATH="build/MonitorBarApp.xcarchive"
EXPORT_PATH="build/export"
DMG_NAME="MonitorBarApp.dmg"

# Собрать архив
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | grep -E "^(error:|warning:|Build succeeded|.* ARCHIVE)"

# Вытащить .app
APP_PATH=$(find "$ARCHIVE_PATH" -name "*.app" | head -1)
mkdir -p "$EXPORT_PATH"
cp -R "$APP_PATH" "$EXPORT_PATH/"

# Собрать DMG через hdiutil
hdiutil create \
  -volname "MonitorBarApp" \
  -srcfolder "$EXPORT_PATH" \
  -ov \
  -format UDZO \
  "build/$DMG_NAME"

echo "✓ Готово: build/$DMG_NAME"
