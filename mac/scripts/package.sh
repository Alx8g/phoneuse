#!/bin/bash
# Builds "Phone Use.app" with the core inside it, signs it, and makes a DMG.
#   mac/scripts/package.sh [--fresh]      --fresh: rebuild the core bundle (bundle_core.py) too
# SIGN_IDENTITY picks the certificate ("Developer ID Application: …" for a release; "-" signs ad hoc, the
# default, which runs on this Mac only). Notarizing needs a Developer ID build; see docs/MAC.md.
set -euo pipefail
cd "$(dirname "$0")/.."
MAC=$PWD
IDENTITY=${SIGN_IDENTITY:--}
ENT=$MAC/PhoneUse/PhoneUse.entitlements
OUT=$MAC/build/release

if [[ "${1:-}" == "--fresh" || ! -d build/core ]]; then
  /opt/homebrew/bin/python3.15 scripts/bundle_core.py build/core
fi

xcodegen generate -q
xcodebuild -project PhoneUseMac.xcodeproj -scheme PhoneUse -configuration Release -derivedDataPath build \
  CODE_SIGN_IDENTITY="$IDENTITY" build -quiet
APP="$OUT/Phone Use.app"
rm -rf "$OUT" && mkdir -p "$OUT"
cp -R "build/Build/Products/Release/Phone Use.app" "$APP"
mkdir -p "$APP/Contents/Resources"
cp -R build/core "$APP/Contents/Resources/core"
find "$APP/Contents/Resources/core" -name __pycache__ -prune -exec rm -rf {} +

# Sign from the inside out: every library and program in the core, then the app. Python and UxPlay load
# libraries this team didn't sign, so they get the app's entitlements (library validation off).
sign() { codesign --force --timestamp=none --options runtime --sign "$IDENTITY" "$@"; }
while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q "Mach-O"; then
    if [[ -x "$f" && "$f" != *.dylib && "$f" != *.so ]]; then sign --entitlements "$ENT" "$f"; else sign "$f"; fi
  fi
done < <(find "$APP/Contents/Resources/core" -type f -print0)
sign --entitlements "$ENT" "$APP"
codesign --verify --deep --strict "$APP" && echo "signed: $(codesign -dv "$APP" 2>&1 | grep Authority= | head -1)"

hdiutil create -quiet -fs HFS+ -volname "Phone Use" -srcfolder "$APP" -ov -format UDZO "$OUT/PhoneUse.dmg"
echo "$APP"
echo "$OUT/PhoneUse.dmg ($(du -h "$OUT/PhoneUse.dmg" | cut -f1))"
