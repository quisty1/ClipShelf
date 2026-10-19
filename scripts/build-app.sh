#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
DESTINATION="${1:-$PROJECT_DIR/dist}"
mkdir -p "$DESTINATION"
DESTINATION="$(cd -- "$DESTINATION" && pwd)"
cd "$PROJECT_DIR"
swift build -c release --product ClipShelf --arch arm64
BINARY_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
APP="$DESTINATION/ClipShelf.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY_DIR/ClipShelf" "$APP/Contents/MacOS/ClipShelf"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.clipshelf.mac</string>
<key>CFBundleName</key><string>ClipShelf</string>
<key>CFBundleDisplayName</key><string>ClipShelf</string>
<key>CFBundleExecutable</key><string>ClipShelf</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>15.4</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPasteboardUsageDescription</key><string>ClipShelf сохраняет локальную историю скопированного текста, ссылок и изображений.</string>
<key>CFBundleDevelopmentRegion</key><string>ru</string>
<key>CFBundleLocalizations</key><array><string>ru</string></array>
</dict></plist>
PLIST
swift "$PROJECT_DIR/scripts/MakeIcon.swift" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier app.clipshelf.mac "$APP"
codesign --verify --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
printf 'Готово: %s\n' "$APP"
