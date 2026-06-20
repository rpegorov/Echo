#!/bin/bash
# build.sh — обёртка над scripts/make-dmg.sh (Release → dist/Echo-<version>.dmg).
# Оставлено для совместимости; вся логика сборки DMG живёт в scripts/make-dmg.sh.
set -e
cd "$(dirname "$0")"
exec ./scripts/make-dmg.sh "$@"
