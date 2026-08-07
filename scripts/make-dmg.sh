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

# --- Подпись ---
# Стабильная подпись нужна не Gatekeeper'у, а TCC: доступы (Accessibility,
# Input Monitoring) привязаны к подписи, и у ad-hoc сборки они слетают после
# каждого обновления. Сертификат создаётся один раз: scripts/setup-signing.sh
SIGN_IDENTITY="Echo Self-Signed"
if security find-certificate -c "$SIGN_IDENTITY" >/dev/null 2>&1; then
  echo "▶ Подписываю сертификатом «$SIGN_IDENTITY» — доступы переживут обновление"
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$SIGN_IDENTITY" CODE_SIGN_STYLE=Manual CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES)
else
  echo "▶ Сертификата «$SIGN_IDENTITY» нет — собираю ad-hoc"
  echo "  (после каждого обновления доступы придётся выдавать заново;"
  echo "   чтобы это прекратить, один раз запусти scripts/setup-signing.sh)"
  SIGN_IDENTITY="-"
  SIGN_ARGS=(CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO)
fi

echo "▶ Архивирую $SCHEME ($CONFIG)…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -archivePath "$ARCHIVE_PATH" \
  "${SIGN_ARGS[@]}" \
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

# Переименование бандла ломает подпись — переподписываем изнутри наружу,
# иначе вложенный Sparkle.framework останется с прежней.
while IFS= read -r nested; do
  codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$nested" >/dev/null 2>&1 || true
done < <(find "$APP_PATH/Contents/Frameworks" -maxdepth 1 -mindepth 1 2>/dev/null)
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP_PATH" >/dev/null 2>&1 || true
codesign --verify --deep --strict "$APP_PATH" 2>&1 | head -3 || true

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
