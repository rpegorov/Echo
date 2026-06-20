#!/bin/bash
#
# make-dmg.sh — собирает Echo.app в Release и упаковывает в DMG для ручной установки.
# Результат: dist/Echo-<version>.dmg с drag-to-Applications.
#
# Зависимости: Xcode (xcodebuild, hdiutil). Опционально create-dmg (brew install create-dmg)
# для более красивого окна — если установлен, используется автоматически.
#
set -euo pipefail

# --- Настройки ---
PROJECT="MonitorBarApp.xcodeproj"
SCHEME="MonitorBarApp"
CONFIG="Release"
APP_DISPLAY="Echo"               # как назвать .app и том DMG

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Echo.xcarchive"
STAGE_DIR="$BUILD_DIR/dmg-src"
DIST_DIR="dist"

echo "▶ Архивирую $SCHEME ($CONFIG)…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | grep -E "^(error:|warning:|.* ARCHIVE|\*\* ARCHIVE)" || true

# --- Достаём собранный .app и переименовываем в Echo.app ---
# INSTALL_PATH = $(USER_APPS_DIR), поэтому .app лежит в Products/Users/<you>/Applications,
# а не в Products/Applications — ищем по всему архиву.
BUILT_APP="$(find "$ARCHIVE_PATH/Products" -name "*.app" -type d | head -1)"
if [[ -z "${BUILT_APP:-}" || ! -d "$BUILT_APP" ]]; then
  echo "✗ Не нашёл .app в архиве: $ARCHIVE_PATH"
  exit 1
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$BUILT_APP" "$STAGE_DIR/$APP_DISPLAY.app"
APP_PATH="$STAGE_DIR/$APP_DISPLAY.app"

# Ad-hoc подпись (на случай, если xcodebuild снял её при переименовании)
codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1 || true

# --- Версия из Info.plist ---
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.0")"
BUILD_NUM="$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1")"

mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/$APP_DISPLAY-$VERSION.dmg"
rm -f "$DMG_PATH"

echo "▶ Версия $VERSION ($BUILD_NUM) → $DMG_PATH"

if command -v create-dmg >/dev/null 2>&1; then
  echo "▶ Использую create-dmg (красивое окно)…"
  create-dmg \
    --volname "$APP_DISPLAY $VERSION" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 110 \
    --icon "$APP_DISPLAY.app" 150 185 \
    --app-drop-link 390 185 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH" >/dev/null
else
  echo "▶ create-dmg не найден — собираю через hdiutil (Applications-симлинк)…"
  ln -sf /Applications "$STAGE_DIR/Applications"
  hdiutil create \
    -volname "$APP_DISPLAY $VERSION" \
    -srcfolder "$STAGE_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null
fi

echo ""
echo "✓ Готово: $DMG_PATH"
echo ""
echo "Примечание про Gatekeeper: сборка подписана ad-hoc и НЕ нотаризована."
echo "При первом запуске у пользователя: правый клик по Echo.app → Open → Open,"
echo "либо снять карантин:  xattr -dr com.apple.quarantine /Applications/Echo.app"
