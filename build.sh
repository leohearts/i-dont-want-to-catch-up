#!/usr/bin/env bash
#
# Builds the overlay APK and packs the flashable Magisk module zip.
#
# Needs aapt2, zipalign and apksigner from Android SDK build-tools, plus any
# android.jar from Android SDK platforms. Point ANDROID_HOME (or ANDROID_SDK_ROOT)
# at your SDK; ~/Android/Sdk is the fallback.
#
# Signing uses ~/.android/debug.keystore by default. Override with:
#   KS=/path/to/keystore KS_PASS=... KEY_ALIAS=... KEY_PASS=... ./build.sh
set -euo pipefail

cd "$(dirname "$0")"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
BT="$(ls -d "$SDK"/build-tools/*/ 2>/dev/null | sort -V | tail -1)"
PLATFORM_JAR="$(ls "$SDK"/platforms/*/android.jar 2>/dev/null | sort -V | tail -1)"

[ -x "${BT}aapt2" ] || { echo "no aapt2 under $SDK/build-tools" >&2; exit 1; }
[ -f "$PLATFORM_JAR" ] || { echo "no android.jar under $SDK/platforms" >&2; exit 1; }

KS="${KS:-$HOME/.android/debug.keystore}"
KS_PASS="${KS_PASS:-android}"
KEY_ALIAS="${KEY_ALIAS:-androiddebugkey}"
KEY_PASS="${KEY_PASS:-android}"

OUT=build
APK_NAME=IdontWantToCatchUp.apk
ZIP_NAME=i-dont-want-to-catch-up.zip

rm -rf "$OUT"
mkdir -p "$OUT"

"${BT}aapt2" compile --dir overlay/res -o "$OUT/res.zip"
# --auto-add-overlay: the resources exist in SystemUI, not in android.jar.
"${BT}aapt2" link -o "$OUT/unsigned.apk" \
    --manifest overlay/AndroidManifest.xml \
    -I "$PLATFORM_JAR" \
    -R "$OUT/res.zip" \
    --auto-add-overlay \
    --min-sdk-version 29 --target-sdk-version 37

"${BT}zipalign" -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
"${BT}apksigner" sign \
    --ks "$KS" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KEY_PASS" \
    --ks-key-alias "$KEY_ALIAS" \
    --out "$OUT/$APK_NAME" "$OUT/aligned.apk"

# Magisk module: module.prop at the zip root, overlay under system/product/overlay.
STAGE="$OUT/module"
mkdir -p "$STAGE/system/product/overlay"
cp module/module.prop "$STAGE/module.prop"
cp "$OUT/$APK_NAME" "$STAGE/system/product/overlay/$APK_NAME"
(cd "$STAGE" && zip -qr "$OLDPWD/$OUT/$ZIP_NAME" module.prop system)

echo
echo "APK:    $OUT/$APK_NAME"
echo "Module: $OUT/$ZIP_NAME"
