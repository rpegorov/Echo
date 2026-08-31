#!/bin/bash
#
# release.sh — собирает DMG и публикует GitHub Release с ассетом.
# Использование:  ./scripts/release.sh [version]
#   version — например 1.0 (по умолчанию берётся из Info.plist).
#
# Требования: GitHub CLI (gh), авторизация (gh auth login), настроенный remote 'origin'.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(awk -F' = ' '/MARKETING_VERSION = /{print $2; exit}' Echo.xcodeproj/project.pbxproj | tr -d ' ;')}"
TAG="v$VERSION"
DMG="dist/Echo-$VERSION.dmg"

# --- Preflight ---
command -v gh >/dev/null 2>&1 || { echo "✗ Нужен GitHub CLI:  brew install gh  &&  gh auth login"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "✗ gh не авторизован:  gh auth login"; exit 1; }
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "✗ Нет git remote 'origin'. Сначала создай репозиторий на GitHub, например:"
  echo "     gh repo create <user>/Echo --public --source=. --remote=origin --push"
  exit 1
fi

# --- Версия в бандле ---
# При GENERATE_INFOPLIST_FILE = YES версия в собранном .app берётся из настроек
# сборки, а не из Info.plist — правка самого файла ни на что не влияет.
# Sparkle сравнивает CFBundleVersion, поэтому держим обе строки равными релизу.
sed -i '' -E "s/(MARKETING_VERSION = ).*/\1$VERSION;/; s/(CURRENT_PROJECT_VERSION = ).*/\1$VERSION;/" \
  Echo.xcodeproj/project.pbxproj

# --- Сборка DMG ---
bash scripts/make-dmg.sh
[[ -f "$DMG" ]] || { echo "✗ DMG не собрался: $DMG"; exit 1; }

# --- Фид обновлений ---
# Подпись EdDSA и запись в docs/appcast.xml должны попасть в main ДО публикации
# релиза: приложение читает фид именно из ветки main.
bash scripts/appcast.sh "$VERSION" "$DMG"
git add Echo/Info.plist Echo.xcodeproj/project.pbxproj docs/appcast.xml
if ! git diff --cached --quiet; then
  git commit -m "release: Echo $VERSION"
  git push origin HEAD
fi

# --- Тег ---
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "▶ Тег $TAG уже существует — пропускаю создание"
else
  git tag -a "$TAG" -m "Echo $VERSION"
  git push origin "$TAG"
fi

# --- Заметки релиза ---
NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
cat > "$NOTES_FILE" <<EOF
**Echo $VERSION** — menu-bar системный монитор для macOS (CPU / RAM / Disk / Network) с утилитами.

### Установка
1. Скачайте \`Echo-$VERSION.dmg\` ниже.
2. Перетащите **Echo.app** в **Applications**.
3. Первый запуск: правый клик по Echo.app → **Open** → **Open** (сборка не нотаризована).
4. Для функций управления окнами выдайте доступ в System Settings → Privacy & Security → Accessibility.
EOF

# --- Релиз ---
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "▶ Релиз $TAG уже есть — догружаю ассет"
  gh release upload "$TAG" "$DMG" --clobber
else
  gh release create "$TAG" "$DMG" --title "Echo $VERSION" --notes-file "$NOTES_FILE"
fi

echo ""
echo "✓ Готово: $(gh release view "$TAG" --json url -q .url 2>/dev/null || echo "$TAG")"
