#!/bin/bash
# Builds the macOS NappyCat widget app + DMG.
#
# A native Swift menu-bar app (single file, no Xcode project) hosting the web
# app's ?mini=1 cat card in a floating WKWebView window — the closest thing to
# a home-screen widget macOS allows an unsigned app. WKWebView is just a
# browser, so sign-in persists in its storage and none of FirebaseAuth's
# data-protection-keychain requirements apply. Supersedes the plain
# Chrome-launcher DMG; "Open NappyCat" in the menu covers the full app.
set -euo pipefail
cd "$(dirname "$0")"

OUT=build
APP="$OUT/NappyCat.app"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal: the partner's Mac may be Intel.
swiftc widget/main.swift -O -target arm64-apple-macos11 -o "$OUT/nappy_arm64" \
  -framework Cocoa -framework WebKit
swiftc widget/main.swift -O -target x86_64-apple-macos11 -o "$OUT/nappy_x86_64" \
  -framework Cocoa -framework WebKit
lipo -create -output "$APP/Contents/MacOS/NappyCat" \
  "$OUT/nappy_arm64" "$OUT/nappy_x86_64"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>NappyCat</string>
  <key>CFBundleDisplayName</key><string>NappyCat</string>
  <key>CFBundleIdentifier</key><string>com.mypeblo.nappycat.widget</string>
  <key>CFBundleVersion</key><string>1.1.0</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>NappyCat</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep -s - "$APP" 2>/dev/null || true

DMGDIR="$OUT/dmg"
mkdir -p "$DMGDIR"
cp -R "$APP" "$DMGDIR/"
ln -s /Applications "$DMGDIR/Applications"
hdiutil create -volname NappyCat -srcfolder "$DMGDIR" -ov -format UDZO \
  "$OUT/NappyCat.dmg" >/dev/null
echo "built: $(pwd)/$OUT/NappyCat.dmg"
