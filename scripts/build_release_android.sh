#!/bin/bash
# ─────────────────────────────────────────────────────────────
# MajuRun — Release Android Build Script
# Usage:
#   ./scripts/build_release_android.sh apk    → builds APK  (device testing)
#   ./scripts/build_release_android.sh aab    → builds AAB  (Play Store upload)
# ─────────────────────────────────────────────────────────────

set -e  # stop on any error

BUILD_TYPE=${1:-apk}
ANDROID_DIR="android"
APP_DIR="$ANDROID_DIR/app"
PROD_JSON="$APP_DIR/google-services-prod.json"
DEV_JSON="$APP_DIR/google-services-dev.json"
ACTIVE_JSON="$APP_DIR/google-services.json"

# ── Validate ──────────────────────────────────────────────────
if [ ! -f "$PROD_JSON" ]; then
  echo "❌ Missing: $PROD_JSON"
  exit 1
fi
if [ ! -f "$ANDROID_DIR/key.properties" ]; then
  echo "❌ Missing: android/key.properties"
  exit 1
fi
if [ ! -f "$ANDROID_DIR/majurun-release.jks" ]; then
  echo "❌ Missing: android/majurun-release.jks"
  exit 1
fi

# ── Swap to PROD google-services.json ─────────────────────────
echo "🔄 Switching to PROD Firebase..."
cp "$PROD_JSON" "$ACTIVE_JSON"

# ── Build ──────────────────────────────────────────────────────
if [ "$BUILD_TYPE" = "aab" ]; then
  echo "🏗️  Building release AAB (Play Store)..."
  flutter build appbundle --release --dart-define=ENVIRONMENT=production
  OUTPUT="build/app/outputs/bundle/release/app-release.aab"
else
  echo "🏗️  Building release APK (device testing)..."
  flutter build apk --release --dart-define=ENVIRONMENT=production
  OUTPUT="build/app/outputs/flutter-apk/app-release.apk"
fi

# ── Restore DEV google-services.json ──────────────────────────
echo "🔄 Restoring DEV Firebase..."
cp "$DEV_JSON" "$ACTIVE_JSON"

# ── Done ───────────────────────────────────────────────────────
echo ""
echo "✅ Build complete!"
echo "📦 Output: $OUTPUT"

if [ "$BUILD_TYPE" = "apk" ]; then
  echo ""
  echo "📲 To install on connected device:"
  echo "   adb install -r $OUTPUT"
  echo ""
  echo "   If multiple devices: adb -s <device-id> install $OUTPUT"
  echo "   Get device ID with: adb devices"
fi
