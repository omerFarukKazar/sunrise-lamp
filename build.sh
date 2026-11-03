#!/bin/bash
# Builds "Sunrise Lamp.app" into ./build from the Swift package.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="build/Sunrise Lamp.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/SunriseLamp" "$APP/Contents/MacOS/SunriseLamp"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "Apple Development" "$APP"
echo "Built $APP"

# The login item points at the installed copy, so keep it in /Applications.
pkill -x SunriseLamp || true
rm -rf "/Applications/Sunrise Lamp.app"
cp -R "$APP" "/Applications/Sunrise Lamp.app"
echo "Installed /Applications/Sunrise Lamp.app"
