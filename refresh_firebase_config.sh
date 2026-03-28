#!/usr/bin/env bash
# refresh_firebase_config.sh
# Run this ONLY when you need to re-download google-services.json after
# Firebase Console changes (new SHA, new service, etc).
# Normal daily dev work does NOT need this — SHA is fixed via shared debug keystore.

set -e

echo "=== Refreshing Firebase configs ==="

# DEV — majurun-dev project
echo "Downloading google-services-dev.json..."
firebase apps:sdkconfig ANDROID 1:852818479467:android:47186545243005b7eee42e \
  --project majurun-dev 2>&1 | grep -v "^-\|^√\|^i " > android/app/google-services-dev.json
cp android/app/google-services-dev.json android/app/google-services.json
echo "  -> google-services.json (dev) updated"

# PROD — majurun-8d8b5 project
echo "Downloading google-services-prod.json..."
firebase apps:sdkconfig ANDROID 1:648836412000:android:015b64300bfff880ac8905 \
  --project majurun-8d8b5 2>&1 | grep -v "^-\|^√\|^i " > android/app/google-services-prod.json
echo "  -> google-services-prod.json updated"

echo ""
echo "=== Done. Commit the updated files: ==="
echo "  git add android/app/google-services*.json"
echo "  git commit -m 'chore: refresh Firebase google-services configs'"
