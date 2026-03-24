# MajuRun Architecture Guide

## Firebase Projects

| Project | ID | Used For |
|---------|-----|----------|
| MajuRun Dev | `majurun-dev` | Local dev, `flutter run`, QA testing |
| MajuRun Prod | `majurun-8d8b5` | Play Store / App Store releases only |

## Environment-Based Firebase Init

Firebase project is selected at **build time** via `--dart-define=ENVIRONMENT=production`.

```
flutter run                                         → majurun-dev   (default)
flutter run --dart-define=ENVIRONMENT=production    → majurun-8d8b5
flutter build appbundle --dart-define=ENVIRONMENT=production → majurun-8d8b5
```

Config files (both committed to git, safe to expose):
- `lib/env/firebase_options_dev.dart`  → majurun-dev
- `lib/env/firebase_options_prod.dart` → majurun-8d8b5

## Firebase Config Files (gitignored — injected by CI)

| File | Secret Name | Used When |
|------|------------|-----------|
| `android/app/google-services.json` | `GOOGLE_SERVICES_JSON_PROD` or `GOOGLE_SERVICES_JSON_DEV` | Android build |
| `ios/Runner/GoogleService-Info.plist` | `GOOGLE_SERVICE_INFO_PLIST_PROD` or `GOOGLE_SERVICE_INFO_PLIST_DEV` | iOS build |

For local dev, these files are provided manually (ask team lead).

## SHA Fingerprints (com.majurun.app — prod Firebase)

| Type | Source | Value |
|------|--------|-------|
| SHA-1 | Release keystore | `F1:B8:01:F0:55:DE:58:3B:2F:89:CB:DC:0E:53:D1:33:28:75:B1:1E` |
| SHA-1 | Debug keystore | `A9:E8:DE:13:8F:8D:B7:00:BC:04:C7:35:4D:3C:EE:85:6C:BD:06:08` |
| SHA-256 | Release keystore | `4C:E8:E1:00:D1:15:DF:98:E7:81:BF:7D:72:A4:ED:F5:6D:83:53:3D:E3:40:51:08:25:88:65:AB:2B:F6:4A:13` |
| SHA-256 | Debug keystore | `E8:9A:76:4D:0D:28:F1:FE:BE:3E:02:60:1B:F0:0E:B2:C9:0A:1E:D0:8B:64:F6:67:3B:45:03:04:85:E6:A5:5B` |
| SHA-1 | Play App Signing | Add after first AAB upload to Play Console |
| SHA-256 | Play App Signing | Add after first AAB upload to Play Console |

## Keystore

- **File**: `android/majurun-release.jks` (gitignored, stored in GitHub secret `KEYSTORE_BASE64`)
- **Alias**: `majurun`
- Passwords stored in GitHub secrets: `KEYSTORE_PASSWORD`, `KEY_PASSWORD`

## GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `GOOGLE_SERVICES_JSON_PROD` | Android prod Firebase config (base64) |
| `GOOGLE_SERVICES_JSON_DEV` | Android dev Firebase config (base64) |
| `GOOGLE_SERVICE_INFO_PLIST_PROD` | iOS prod Firebase config (base64) |
| `GOOGLE_SERVICE_INFO_PLIST_DEV` | iOS dev Firebase config (base64) |
| `KEYSTORE_BASE64` | Android release keystore (base64) |
| `KEYSTORE_PASSWORD` | Keystore store password |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |
| `BUILD_CERTIFICATE_BASE64` | iOS distribution certificate (base64) |
| `BUILD_PROVISION_PROFILE_BASE64` | iOS provisioning profile (base64) |
| `P12_PASSWORD` | iOS certificate password |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | Google Play service account JSON |

## GitHub Actions Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `android-build.yml` | Manual | Builds AAB or APK for dev or prod, deploys prod AAB to Play Store internal track |
| `ios-build.yml` | Manual | Builds IPA, uploads to App Store Connect |

## Rule: After Any Firebase Console Change

```bash
# Re-generate configs (run for whichever project changed)
flutterfire configure --project=majurun-8d8b5 --out=lib/env/firebase_options_prod.dart --platforms=android,ios,web --android-package-name=com.majurun.app --ios-bundle-id=com.majurun.app -y

flutterfire configure --project=majurun-dev --out=lib/env/firebase_options_dev.dart --platforms=android,ios,web --android-package-name=com.majurun.app --ios-bundle-id=com.majurun.app -y

# Update GitHub secrets with new configs
base64 -w 0 android/app/google-services-prod.json | gh secret set GOOGLE_SERVICES_JSON_PROD
base64 -w 0 android/app/google-services-dev.json | gh secret set GOOGLE_SERVICES_JSON_DEV
base64 -w 0 ios/Runner/GoogleService-Info-Prod.plist | gh secret set GOOGLE_SERVICE_INFO_PLIST_PROD
base64 -w 0 ios/Runner/GoogleService-Info-Dev.plist | gh secret set GOOGLE_SERVICE_INFO_PLIST_DEV

# Commit dart config files
git add lib/env/firebase_options_dev.dart lib/env/firebase_options_prod.dart
git commit -m "chore: update Firebase config"
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `firebase_auth/api-key-expired` | Old key in config | Run `flutterfire configure` and update secrets |
| `app not authorized, sha-1 sha-256` | SHA not registered | Add SHA to Firebase Console → Project Settings → Your apps |
| `play_integrity_token no matching sha-256` | Play signing SHA missing | Get SHA from Play Console → App integrity → App signing, add to Firebase |
| `requests from this Android client blocked` | Wrong appId or OAuth client | Run `flutterfire configure` to regenerate correct appId |
| Config out of sync after Firebase change | Manual edits | Follow "After Any Firebase Console Change" steps above |

## Firebase Console Logins Required

After creating `majurun-dev` project, enable these manually in Firebase Console:
- Authentication → Sign-in method: Email/Password, Phone, Google
- Firestore Database → Create database
- Storage → Get started
- Add debug SHA fingerprints to the dev Android app
