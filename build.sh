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

# Copy Info.plist
cp "Sources/CmdVPasteClaude/Info.plist" "$APP_BUNDLE/Contents/"

# Copy icon
cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

echo "Build complete: $APP_BUNDLE"
echo ""
echo "To install, drag $APP_BUNDLE to /Applications"
