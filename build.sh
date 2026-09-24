#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="iEdit"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Cleaning previous build"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

echo "==> Compiling Swift sources (universal: arm64 + x86_64, macOS 13+)"
SRC_FILES=(Sources/iEdit/*.swift Sources/iEdit/FindReplace/*.swift)

swiftc -O -target arm64-apple-macosx13.0 \
    -o "$BUILD_DIR/${APP_NAME}-arm64" \
    "${SRC_FILES[@]}" -framework Cocoa

swiftc -O -target x86_64-apple-macosx13.0 \
    -o "$BUILD_DIR/${APP_NAME}-x86_64" \
    "${SRC_FILES[@]}" -framework Cocoa

lipo -create "$BUILD_DIR/${APP_NAME}-arm64" "$BUILD_DIR/${APP_NAME}-x86_64" \
    -output "$BUILD_DIR/$APP_NAME"

echo "==> Generating app icon"
mkdir -p "$BUILD_DIR/AppIcon.iconset"
swift Scripts/GenerateIcon.swift "$BUILD_DIR/AppIcon.iconset" > /dev/null
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$BUILD_DIR/AppIcon.icns"

echo "==> Assembling app bundle"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> Code signing (ad-hoc)"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
