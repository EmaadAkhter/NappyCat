#!/bin/bash
# Builds the macOS "NappyCat" launcher app + DMG.
#
# Deliberately NOT the Flutter macOS build: FirebaseAuth forces the
# data-protection keychain on macOS (AuthKeychainServices.swift sets
# kSecUseDataProtectionKeychain unconditionally), which only works in an
# Apple-provisioned, paid-account-signed app. Unsigned, every auth call dies
# with keychain-error — so a native build can never keep you signed in.
#
# Instead the DMG ships a tiny app that opens the deployed web app in a
# Chrome app-mode window with its own browser profile: sign-in persists in
# that profile's IndexedDB, the window is phone-shaped like the real app, and
# every `firebase deploy` updates desktop users for free.
set -euo pipefail
cd "$(dirname "$0")"

URL="https://napcat-2e042.web.app/"
OUT=build
APP="$OUT/NappyCat.app"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>NappyCat</string>
  <key>CFBundleDisplayName</key><string>NappyCat</string>
  <key>CFBundleIdentifier</key><string>com.mypeblo.nappycat.launcher</string>
  <key>CFBundleVersion</key><string>1.0.0</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>NappyCat</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cat > "$APP/Contents/MacOS/NappyCat" <<'LAUNCH'
#!/bin/bash
URL="https://napcat-2e042.web.app/"
PROFILE="$HOME/Library/Application Support/NappyCat/Browser"
mkdir -p "$PROFILE"
for NAME in "Google Chrome" "Brave Browser" "Microsoft Edge" "Chromium" "Vivaldi"; do
  for BASE in "/Applications" "$HOME/Applications"; do
    A="$BASE/$NAME.app"
    [ -d "$A" ] || continue
    BIN="$A/Contents/MacOS/$(defaults read "$A/Contents/Info" CFBundleExecutable 2>/dev/null)"
    [ -x "$BIN" ] || continue
    exec "$BIN" --app="$URL" --window-size=430,800 --user-data-dir="$PROFILE" \
      --no-first-run --no-default-browser-check
  done
done
# No Chromium-family browser: plain tab in the default browser. Safari caps
# script-writable storage at ~7 days, so pairing may not survive there —
# the README tells people to install Chrome for the real experience.
exec /usr/bin/open "$URL"
LAUNCH
chmod +x "$APP/Contents/MacOS/NappyCat"

# Reuse the real app icon if a native build has ever produced one.
ICNS="../../build/macos/Build/Products/Release/NappyCat.app/Contents/Resources/AppIcon.icns"
[ -f "$ICNS" ] && cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep -s - "$APP" 2>/dev/null || true

DMGDIR="$OUT/dmg"
mkdir -p "$DMGDIR"
cp -R "$APP" "$DMGDIR/"
ln -s /Applications "$DMGDIR/Applications"
hdiutil create -volname NappyCat -srcfolder "$DMGDIR" -ov -format UDZO \
  "$OUT/NappyCat.dmg" >/dev/null
echo "built: $(pwd)/$OUT/NappyCat.dmg"
