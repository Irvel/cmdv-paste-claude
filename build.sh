#!/bin/bash
set -e

echo "Building CmdVPasteClaude..."

# Build the executable
swift build -c release

# Create app bundle structure
APP_NAME="CmdVPasteClaude"
APP_BUNDLE="$APP_NAME.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy resources
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"
cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
cp "Resources/menubar_icon.png" "$APP_BUNDLE/Contents/Resources/"
cp "Resources/menubar_icon@2x.png" "$APP_BUNDLE/Contents/Resources/"

echo "Build complete: $APP_BUNDLE"
echo ""
echo "To install, drag $APP_BUNDLE to /Applications"
