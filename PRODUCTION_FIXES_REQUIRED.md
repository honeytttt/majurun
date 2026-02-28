# MajuRun Production Fixes Required

## Status Summary

| Item | Status |
|------|--------|
| Crashlytics | ✅ DONE |
| Analytics | ✅ DONE |
| Input Validation | ✅ DONE |
| Account Deletion (GDPR) | ✅ DONE |
| Password Strength | ✅ DONE |
| Connectivity Service | ✅ DONE |
| Bundle ID Change | ⚠️ MANUAL REQUIRED |
| Background Location Config | ⚠️ MANUAL REQUIRED |
| Health Permissions | ⚠️ MANUAL REQUIRED |

---

## COMPLETED ✅

### 1. Crashlytics Integration
- **File:** `lib/core/services/crash_reporting_service.dart`
- **Package:** `firebase_crashlytics: ^4.3.10` (added to pubspec.yaml)
- **Status:** Fully integrated with global error handling
- **Features:**
  - Global Flutter error handling
  - Async error capture
  - Custom key-value logging
  - User identification
  - Context-specific error methods (network, auth, location, database, workout, payment)

### 2. Analytics Integration
- **File:** `lib/core/services/analytics_service.dart`
- **Package:** `firebase_analytics: ^11.6.0` (added to pubspec.yaml)
- **Status:** Fully integrated with event logging
- **Features:**
  - Screen view tracking
  - Custom event logging
  - User identification
  - Pre-built events for runs, workouts, achievements, social, training, subscriptions

### 3. Input Validation
- **File:** `lib/core/utils/input_validators.dart`
- **Status:** Complete validation utilities
- **Features:**
  - Email validation
  - Password strength validation (8+ chars, uppercase, lowercase, numbers, special chars)
  - Username validation
  - Display name validation
  - Numeric input validation (weight, height, age)
  - Post/comment length validation
  - Input sanitization
  - Malicious content detection

### 4. Password Strength Indicator
- **File:** `lib/core/widgets/password_strength_indicator.dart`
- **Status:** Ready to use in auth screens
- **Features:**
  - Visual strength bar with gradient colors
  - Strength labels (Weak, Fair, Good, Strong)
  - Requirement checklist
  - Integrated password field with strength indicator

### 5. Account Deletion (GDPR/CCPA)
- **File:** `lib/core/services/account_deletion_service.dart`
- **Status:** Complete
- **Features:**
  - Full data deletion from Firestore
  - Firebase Auth account deletion
  - Local storage cleanup
  - Data export for portability

### 6. Connectivity Service
- **File:** `lib/core/services/connectivity_service.dart`
- **Package:** `connectivity_plus: ^6.1.5` (added to pubspec.yaml)
- **Status:** Complete
- **Features:**
  - Network monitoring with DNS lookup
  - Stream-based connectivity updates
  - Mixin for widget connectivity awareness

---

## MANUAL STEPS REQUIRED ⚠️

### 1. Bundle ID Change (CRITICAL)

**Current:** `com.example.majurun`
**Required:** `com.majurun.app` (or your registered domain)

**Steps:**
1. Go to Firebase Console → Project Settings → Your Apps
2. Add new iOS app with bundle ID `com.majurun.app`
3. Add new Android app with package name `com.majurun.app`
4. Download new `google-services.json` and `GoogleService-Info.plist`
5. Replace the files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
6. Run: `flutterfire configure` to regenerate `firebase_options.dart`

**Files to update manually:**
```
android/app/build.gradle
└── applicationId "com.majurun.app"

ios/Runner.xcodeproj/project.pbxproj
└── PRODUCT_BUNDLE_IDENTIFIER = com.majurun.app

ios/Runner/Info.plist
└── CFBundleIdentifier = com.majurun.app
```

---

### 2. Background Location (iOS/Android Config)

**Android:** Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- Add these permissions -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Add this service inside <application> -->
<service
    android:name="com.google.android.gms.location.LocationUpdatesService"
    android:foregroundServiceType="location"
    android:exported="false" />
```

**iOS:** Add to `ios/Runner/Info.plist`:
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>MajuRun needs location access to track your runs even when the app is in the background.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>MajuRun needs location access to track your runs.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
</array>
```

---

### 3. Health Data Permissions (iOS Only)

Add to `ios/Runner/Info.plist`:
```xml
<key>NSHealthShareUsageDescription</key>
<string>MajuRun syncs your running data with Apple Health.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>MajuRun saves your running workouts to Apple Health.</string>
```

---

### 4. Android Target SDK

Update `android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 34
    }
}
```

---

## FILES CREATED FOR PRODUCTION

| File | Purpose |
|------|---------|
| `lib/core/services/account_deletion_service.dart` | GDPR/CCPA compliance |
| `lib/core/services/analytics_service.dart` | Firebase Analytics wrapper |
| `lib/core/services/crash_reporting_service.dart` | Crashlytics wrapper |
| `lib/core/services/connectivity_service.dart` | Network monitoring |
| `lib/core/utils/input_validators.dart` | Password strength & input validation |
| `lib/core/widgets/password_strength_indicator.dart` | Password UI component |

---

## CHECKLIST BEFORE SUBMISSION

### iOS App Store
- [ ] Bundle ID changed from `com.example.majurun`
- [ ] Privacy Policy URL set in App Store Connect
- [ ] Health permissions descriptions in Info.plist
- [ ] Background location enabled in Capabilities
- [ ] App icons for all sizes generated
- [ ] Screenshots for all device sizes
- [ ] App description and keywords
- [ ] Age rating configured

### Google Play Store
- [ ] Package name changed from `com.example.majurun`
- [ ] Target SDK set to 34
- [ ] Privacy Policy URL in Play Console
- [ ] Data Safety form completed
- [ ] Content rating questionnaire completed
- [ ] App signing configured
- [ ] Release notes written
- [ ] Feature graphic (1024x500)

### Code Quality
- [x] Crashlytics integrated and tested
- [x] Analytics events implemented
- [x] Account deletion flow working
- [x] Password validation enabled
- [x] Input validation implemented
- [ ] All errors handled gracefully
- [ ] Offline mode tested

---

## QUICK START COMMANDS

```bash
# Run app in debug mode
flutter run

# Build release APK (Android)
flutter build apk --release

# Build release IPA (iOS)
flutter build ios --release

# Run tests
flutter test

# Analyze code
flutter analyze
```

---

## POST-LAUNCH MONITORING

1. **Crashlytics Dashboard:** Monitor crash-free users and fix critical issues
2. **Analytics Dashboard:** Track user engagement and feature usage
3. **User Reviews:** Respond within 24-48 hours
4. **Performance:** Monitor app startup time and memory usage
5. **Updates:** Plan feature updates based on analytics data

---

## SUPPORT RESOURCES

- Firebase Console: https://console.firebase.google.com
- App Store Connect: https://appstoreconnect.apple.com
- Google Play Console: https://play.google.com/console
- Flutter Docs: https://flutter.dev/docs
