#!/usr/bin/env bash
# Build Claudex from source and install it to /Applications/Claudex.app.
#
# Why /Applications instead of running from DerivedData: macOS notification
# services (UNUserNotificationCenter, etc.) refuse to talk to apps running
# from a non-stable path. Installing once into /Applications fixes that.
#
# Usage: ./scripts/install.sh

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install it with: brew install xcodegen"
    exit 1
fi

echo "▸ Generating Claudex.xcodeproj…"
xcodegen generate >/dev/null

echo "▸ Building (Debug, signed with Apple Development cert)…"
xcodebuild \
    -project Claudex.xcodeproj \
    -scheme Claudex \
    -configuration Debug \
    -destination 'platform=macOS' \
    build >/dev/null

APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Claudex-*/Build/Products/Debug/Claudex.app 2>/dev/null | head -1)
if [ -z "$APP" ]; then
    echo "Could not locate built Claudex.app under DerivedData."
    exit 1
fi

echo "▸ Stopping any running instance…"
killall Claudex 2>/dev/null || true

echo "▸ Installing to /Applications/Claudex.app…"
rm -rf /Applications/Claudex.app
cp -R "$APP" /Applications/Claudex.app

echo "▸ Registering with Launch Services…"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f /Applications/Claudex.app

echo "▸ Launching…"
open /Applications/Claudex.app

echo "✓ Claudex installed and running."
