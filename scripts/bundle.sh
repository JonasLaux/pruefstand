#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="Pruefstand.app"
BUNDLE_ID="com.jonaslaux.pruefstand"
EXEC="Pruefstand"

echo "Building release binary..."
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$EXEC"

if [[ ! -f "$BIN" ]]; then
    echo "Build produced no binary at $BIN" >&2
    exit 1
fi

echo "Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXEC"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Pruefstand</string>
    <key>CFBundleDisplayName</key>
    <string>Pruefstand</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>$EXEC</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Local build</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so notifications + Gatekeeper behave on the local machine.
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "codesign skipped"

echo "Done: $APP"
echo "Run it:  open \"$APP\""
