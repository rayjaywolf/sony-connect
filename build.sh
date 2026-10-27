#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
app="$HOME/Applications/XM6 Control.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/XM6Control "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
mkdir -p "$app/Contents/Resources"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
codesign --force --sign - "$app"
echo "$app"
