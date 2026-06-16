#!/usr/bin/env bash
# Build, sign, notarize, and package MenuBarFolder as a distributable DMG.
#
# This is a PERSONAL project: it signs with Ilya's personal Developer ID and
# explicitly refuses the Cubios Inc business certificate.
#
# One-time setup (already done on this machine via the ioDiacritics project):
#   - Personal "Developer ID Application: Ilya Osipov (TEAMID)" cert in keychain.
#   - notarytool credentials stored as a keychain profile (default: iodia-notary):
#       xcrun notarytool store-credentials "iodia-notary" \
#         --apple-id <id> --team-id <TEAMID> --password <app-specific-password>
#
# Usage:   scripts/build_app.sh
# Env:
#   SIGN_ID=<hash|name>     pick signing identity explicitly
#   NOTARY_PROFILE=<name>   notarytool keychain profile (default: iodia-notary)
#   SKIP_NOTARIZE=1         sign + build the DMG but skip notarization/staple
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="MenuBarFolder"
BUNDLE_ID="com.ctrl8.MenuBarFolder"
NOTARY_PROFILE="${NOTARY_PROFILE:-iodia-notary}"

VERSION="$(/usr/bin/grep -E 'static let version' "$ROOT/Sources/MenuBarFolder/AppInfo.swift" \
  | /usr/bin/sed -E 's/.*"([^"]+)".*/\1/')"
[[ -z "$VERSION" ]] && VERSION="0.0.0"

DIST="$ROOT/dist"
APP_DIR="$DIST/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

echo "==> Building $APP_NAME $VERSION (universal release)"
swift build -c release --arch arm64 --arch x86_64

BIN="$ROOT/.build/apple/Products/Release/$APP_NAME"
[[ -f "$BIN" ]] || BIN="$ROOT/.build/release/$APP_NAME"
[[ -f "$BIN" ]] || { echo "!! binary not found" >&2; exit 1; }

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

echo "==> Generating AppIcon.icns from the app's own drawing code"
ICON_PNG="$DIST/AppIcon-1024.png"
"$BIN" --export-icon "$ICON_PNG"
ICONSET="$ROOT/.build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size*2))" "$((size*2))" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Ilya Osipov (iLya Os). MIT licensed.</string>
</dict>
</plist>
PLIST
echo "APPL????" > "$CONTENTS/PkgInfo"

# Resolve a PERSONAL Developer ID identity (never the Cubios business cert).
SIGN_ID="${SIGN_ID:-}"
if [[ -z "$SIGN_ID" ]]; then
  SIGN_ID="$(security find-identity -v -p codesigning \
    | awk '/Developer ID Application/ && !/Cubios/ {print $2; exit}')"
fi
[[ -n "$SIGN_ID" ]] || { echo "!! no personal Developer ID Application identity found" >&2; exit 1; }
echo "==> Codesigning with $SIGN_ID"
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

echo "==> Building DMG (drag-to-Applications layout)"
STAGE="$DIST/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP_DIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
rm -rf "$STAGE"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  echo "==> SKIP_NOTARIZE=1 — DMG signed but NOT notarized."
elif xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "==> Notarizing DMG (profile: $NOTARY_PROFILE) — a few minutes..."
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo "==> Gatekeeper assessment:"
  spctl --assess -vvv --type open --context context:primary-signature "$DMG" || true
else
  echo "!! notary profile '$NOTARY_PROFILE' not available — DMG signed but NOT notarized." >&2
fi

echo "==> Done:"
echo "    $APP_DIR"
echo "    $DMG"
