#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Build FitTrack.apk without Gradle, using only the Android SDK build tools.
# Handy on machines where Gradle/AGP cannot download dependencies.
#
#   JAVA_HOME=/path/to/jdk17  ANDROID_HOME=/path/to/android-sdk  ./scripts/build_apk.sh
#
# Output: dist/FitTrack.apk
# ---------------------------------------------------------------------------
set -euo pipefail

: "${ANDROID_HOME:?set ANDROID_HOME to your Android SDK path}"
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$PROJ/build/cli"

BT="$(ls -d "$ANDROID_HOME"/build-tools/*/ | sort -V | tail -1)"
BT="${BT%/}"
ANDROID_JAR="$(ls -d "$ANDROID_HOME"/platforms/android-*/ | sort -V | tail -1)android.jar"

rm -rf "$BUILD"; mkdir -p "$BUILD/gen" "$BUILD/classes" "$BUILD/dex"
cd "$PROJ"

echo "==> aapt2 compile"
"$BT/aapt2" compile --dir app/src/main/res -o "$BUILD/res.zip"

echo "==> aapt2 link"
sed 's|<manifest xmlns:android="http://schemas.android.com/apk/res/android"|<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.rekha.fitnesstracker"|' \
  app/src/main/AndroidManifest.xml > "$BUILD/AndroidManifest.xml"
"$BT/aapt2" link \
  -o "$BUILD/base.apk" \
  -I "$ANDROID_JAR" \
  --manifest "$BUILD/AndroidManifest.xml" \
  -R "$BUILD/res.zip" \
  -A app/src/main/assets \
  --java "$BUILD/gen" \
  --min-sdk-version 21 --target-sdk-version 34 \
  --version-code 1 --version-name 1.0 \
  --auto-add-overlay

echo "==> javac"
find "$BUILD/gen" app/src/main/java -name '*.java' > "$BUILD/sources.txt"
javac --release 8 -nowarn -classpath "$ANDROID_JAR" -d "$BUILD/classes" @"$BUILD/sources.txt"

echo "==> d8"
find "$BUILD/classes" -name '*.class' > "$BUILD/classes.txt"
"$BT/d8" --lib "$ANDROID_JAR" --min-api 21 --output "$BUILD/dex" @"$BUILD/classes.txt"

echo "==> package dex"
python3 - "$BUILD/base.apk" "$BUILD/dex/classes.dex" <<'PY'
import sys, zipfile, shutil
apk, dex = sys.argv[1], sys.argv[2]
shutil.copyfile(apk, apk + ".tmp")
with zipfile.ZipFile(apk + ".tmp", "a", zipfile.ZIP_DEFLATED) as z:
    z.write(dex, "classes.dex")
shutil.move(apk + ".tmp", apk)
PY

echo "==> zipalign"
"$BT/zipalign" -p -f 4 "$BUILD/base.apk" "$BUILD/aligned.apk"

echo "==> sign (debug keystore, created on first run)"
KS="$PROJ/build/fittrack-debug.keystore"
if [ ! -f "$KS" ]; then
  keytool -genkeypair -keystore "$KS" -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=FitTrack Debug,O=FitTrack,C=IN" >/dev/null 2>&1
fi
mkdir -p "$PROJ/dist"
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android \
  --out "$PROJ/dist/FitTrack.apk" "$BUILD/aligned.apk"

"$BT/apksigner" verify --print-certs "$PROJ/dist/FitTrack.apk" | head -3
echo "APK ready: $PROJ/dist/FitTrack.apk"
