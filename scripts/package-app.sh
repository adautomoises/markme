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
cp App/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"

# The Finder app is /Applications/Markme.app. The copy in this folder is only
# the build product, so it is unregistered and does not stay as a second app.
osascript -e 'tell application id "app.markme.viewer" to quit' >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x Markme >/dev/null || break
  sleep 0.3
done
if pgrep -x Markme >/dev/null; then
  pkill -x Markme || true
  sleep 0.5
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
INSTALLED="/Applications/$APP"
rm -rf "$INSTALLED"
ditto "$PWD/$APP" "$INSTALLED"
codesign --force --deep --sign - "$INSTALLED"
"$LSREGISTER" -f "$INSTALLED"
"$LSREGISTER" -u "$PWD/$APP" >/dev/null 2>&1 || true
rm -rf "$PWD/$APP"
"$LSREGISTER" -gc >/dev/null

SETDEFAULT="$(mktemp /tmp/markme-setdefault.XXXXXX.swift)"
cat > "$SETDEFAULT" <<'SWIFT'
import AppKit
import UniformTypeIdentifiers

let bundle = URL(fileURLWithPath: "/Applications/Markme.app")
var identifiers = Set<String>()
var types: [UTType] = []
if let markdown = UTType("net.daringfireball.markdown") {
    types.append(markdown)
}
types += ["md", "markdown", "mdown", "mkd", "mdwn"].compactMap { UTType(filenameExtension: $0) }
let chosen = types.filter { identifiers.insert($0.identifier).inserted }
var left = chosen.count
guard left > 0 else { exit(0) }
for type in chosen {
    NSWorkspace.shared.setDefaultApplication(at: bundle, toOpen: type) { error in
        if let error {
            fputs("\(type.identifier): \(error)\n", stderr)
        }
        left -= 1
        if left == 0 { CFRunLoopStop(CFRunLoopGetMain()) }
    }
}
CFRunLoopRun()
SWIFT
swift "$SETDEFAULT"
rm -f "$SETDEFAULT"
