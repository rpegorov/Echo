#!/bin/bash
set -euo pipefail

SCHEME="Echo"
CONFIG="Debug"
APP_NAME="Echo"

echo "▶ Building $APP_NAME ($CONFIG)..."

BUILD_LOG=$(mktemp)
trap 'rm -f "$BUILD_LOG"' EXIT

if xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    build \
    > "$BUILD_LOG" 2>&1; then

    grep -E "warning:" "$BUILD_LOG" | grep -v "appintents\|Metadata extraction" || true
    echo "✓ Build succeeded"
else
    grep -E "error:|warning:|BUILD " "$BUILD_LOG" | grep -v "appintents\|Metadata extraction"
    echo "✗ Build failed"
    exit 1
fi

BUILD_DIR=$(xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -showBuildSettings 2>/dev/null \
    | grep "BUILT_PRODUCTS_DIR" \
    | head -1 \
    | sed 's/.*= //')

APP_PATH="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "✗ App not found: $APP_PATH"
    exit 1
fi

if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    echo "▶ Stopping previous instance..."
    pkill -x "$APP_NAME"
    sleep 0.5
fi

echo "▶ Launching $APP_PATH"
open "$APP_PATH"
