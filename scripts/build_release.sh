#!/bin/bash
# MajuRun Release Build Script
# Usage: ./scripts/build_release.sh [android|ios|both]

set -e

# Load environment variables from .env file
if [ -f .env ]; then
    echo "Loading environment from .env..."
    export $(grep -v '^#' .env | xargs)
else
    echo "ERROR: .env file not found!"
    echo "Copy .env.example to .env and fill in your values."
    exit 1
fi

# Validate required variables
if [ -z "$CLOUDINARY_CLOUD_NAME" ] || [ -z "$CLOUDINARY_API_KEY" ] || [ -z "$CLOUDINARY_UPLOAD_PRESET" ]; then
    echo "ERROR: Missing required Cloudinary configuration!"
    echo "Please set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_UPLOAD_PRESET in .env"
    exit 1
fi

# Build dart-define arguments
DART_DEFINES=""
DART_DEFINES="$DART_DEFINES --dart-define=ENVIRONMENT=${ENVIRONMENT:-production}"
DART_DEFINES="$DART_DEFINES --dart-define=CLOUDINARY_CLOUD_NAME=$CLOUDINARY_CLOUD_NAME"
DART_DEFINES="$DART_DEFINES --dart-define=CLOUDINARY_API_KEY=$CLOUDINARY_API_KEY"
DART_DEFINES="$DART_DEFINES --dart-define=CLOUDINARY_UPLOAD_PRESET=$CLOUDINARY_UPLOAD_PRESET"

[ -n "$WEATHER_API_KEY" ] && DART_DEFINES="$DART_DEFINES --dart-define=WEATHER_API_KEY=$WEATHER_API_KEY"
[ -n "$GOOGLE_MAPS_KEY" ] && DART_DEFINES="$DART_DEFINES --dart-define=GOOGLE_MAPS_KEY=$GOOGLE_MAPS_KEY"
[ -n "$RECAPTCHA_KEY" ] && DART_DEFINES="$DART_DEFINES --dart-define=RECAPTCHA_KEY=$RECAPTCHA_KEY"
[ -n "$API_BASE_URL" ] && DART_DEFINES="$DART_DEFINES --dart-define=API_BASE_URL=$API_BASE_URL"

echo "Building with environment: ${ENVIRONMENT:-production}"

PLATFORM=${1:-both}

if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "both" ]; then
    echo ""
    echo "=========================================="
    echo "Building Android App Bundle..."
    echo "=========================================="
    flutter build appbundle --release $DART_DEFINES
    echo ""
    echo "Android AAB: build/app/outputs/bundle/release/app-release.aab"
fi

if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "both" ]; then
    echo ""
    echo "=========================================="
    echo "Building iOS IPA..."
    echo "=========================================="
    flutter build ipa --release $DART_DEFINES
    echo ""
    echo "iOS IPA: build/ios/ipa/*.ipa"
fi

echo ""
echo "Build complete!"
