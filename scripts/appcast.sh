#!/bin/bash
#
# appcast.sh — подписывает собранный DMG ключом Sparkle (EdDSA) и добавляет
# запись о версии в docs/appcast.xml.
#
# Использование:  ./scripts/appcast.sh <version> <path-to-dmg> [notes-file]
#
# Приватный ключ лежит в связке ключей (создан через generate_keys) и здесь
# не хранится. Публичный — в MonitorBarApp/Info.plist (SUPublicEDKey).
#
set -euo pipefail

VERSION="${1:?Укажи версию, например 1.1}"
DMG="${2:?Укажи путь к DMG}"
NOTES_FILE="${3:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APPCAST="docs/appcast.xml"
REPO_SLUG="rpegorov/Echo"
DOWNLOAD_URL="https://github.com/$REPO_SLUG/releases/download/v$VERSION/$(basename "$DMG")"

[[ -f "$DMG" ]] || { echo "✗ Нет файла: $DMG"; exit 1; }

# --- Инструменты Sparkle из resolved-пакета SPM ---
BUILD_DIR="$(xcodebuild -project MonitorBarApp.xcodeproj -scheme MonitorBarApp -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *BUILD_DIR = /{print $2; exit}')"
TOOLS="${BUILD_DIR%/Build/Products}/SourcePackages/artifacts/sparkle/Sparkle/bin"
if [[ ! -x "$TOOLS/sign_update" ]]; then
  TOOLS="$(dirname "$(find ~/Library/Developer/Xcode/DerivedData -path '*artifacts/sparkle/Sparkle/bin/sign_update' 2>/dev/null | head -1)")"
fi
[[ -x "$TOOLS/sign_update" ]] || {
  echo "✗ Не найден sign_update. Сначала:  xcodebuild -project MonitorBarApp.xcodeproj -resolvePackageDependencies"
  exit 1
}

echo "▶ Подписываю $DMG…"
SIGN_OUTPUT="$("$TOOLS/sign_update" "$DMG")"   # sparkle:edSignature="…" length="…"
echo "  $SIGN_OUTPUT"

MIN_OS="$(awk -F' = ' '/MACOSX_DEPLOYMENT_TARGET = /{print $2; exit}' MonitorBarApp.xcodeproj/project.pbxproj | tr -d ' ;')"

NOTES=""
[[ -n "$NOTES_FILE" && -f "$NOTES_FILE" ]] && NOTES="$(cat "$NOTES_FILE")"

VERSION="$VERSION" URL="$DOWNLOAD_URL" SIGN="$SIGN_OUTPUT" MIN_OS="${MIN_OS:-26.1}" \
NOTES="$NOTES" APPCAST="$APPCAST" python3 scripts/appcast_merge.py

echo "✓ $APPCAST обновлён: версия $VERSION"
