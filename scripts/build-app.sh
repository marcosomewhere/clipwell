#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="${APP_NAME:-Clipwell}"
PRODUCT_NAME="${PRODUCT_NAME:-Clipwell}"
BUNDLE_ID="${BUNDLE_ID:-com.clipwell.app}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_SRC="$ROOT_DIR/Sources/Clipwell/Resources/Assets.xcassets/AppIcon.appiconset"
ICONSET_TMP="$DIST_DIR/AppIcon.iconset"
INFO_PLIST_SRC="$ROOT_DIR/Sources/Clipwell/Info.plist"

echo "Building $PRODUCT_NAME ($CONFIGURATION)..."
swift build -c "$CONFIGURATION" --package-path "$ROOT_DIR"

BUILD_DIR="$(swift build -c "$CONFIGURATION" --package-path "$ROOT_DIR" --show-bin-path)"
BINARY_PATH="$BUILD_DIR/$PRODUCT_NAME"
RESOURCE_BUNDLE="$BUILD_DIR/Clipwell_Clipwell.bundle"

if [[ ! -x "$BINARY_PATH" ]]; then
    echo "error: expected executable at $BINARY_PATH" >&2
    exit 1
fi

rm -rf "$APP_PATH" "$ICONSET_TMP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_TMP"

cp "$BINARY_PATH" "$MACOS_DIR/$PRODUCT_NAME"
cp "$INFO_PLIST_SRC" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $PRODUCT_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $PRODUCT_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS_DIR/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$CONTENTS_DIR/Info.plist"

cp "$ICONSET_SRC"/icon_*.png "$ICONSET_TMP"/
iconutil -c icns "$ICONSET_TMP" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_TMP"

if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
plutil -lint "$CONTENTS_DIR/Info.plist"

echo "Created $APP_PATH"
