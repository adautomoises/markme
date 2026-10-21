#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="Markme.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Markme "$APP/Contents/MacOS/Markme"
cp App/Info.plist "$APP/Contents/Info.plist"
cp App/Resources/highlight.min.js "$APP/Contents/Resources/highlight.min.js"
cp App/Resources/dart.js "$APP/Contents/Resources/dart.js"
cp App/Resources/mermaid.min.js "$APP/Contents/Resources/mermaid.min.js"
codesign --force --deep --sign - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$PWD/$APP"
