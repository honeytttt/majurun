# MajuRun - Production Release Checklist

## Pre-Release Checklist for iOS App Store & Google Play

---

## 1. App Configuration

### iOS (App Store Connect)
- [ ] **Bundle ID**: Update `PRODUCT_BUNDLE_IDENTIFIER` in Xcode (e.g., `com.yourcompany.majurun`)
- [ ] **App Name**: "MajuRun" - Verified in Info.plist
- [ ] **Version**: Update in `pubspec.yaml` (e.g., `1.0.0+1`)
- [ ] **Minimum iOS Version**: iOS 13.0 or higher recommended
- [ ] **App Icons**: Generate using `flutter pub run flutter_launcher_icons`
- [ ] **Launch Screen**: Customize `LaunchScreen.storyboard` in Xcode

### Android (Google Play Console)
- [ ] **Package Name**: Change from `com.example.majurun` to your actual package
  - Update in `android/app/build.gradle.kts` (applicationId)
  - Update in `android/app/src/main/AndroidManifest.xml`
- [ ] **Version Code/Name**: Update in `pubspec.yaml`
- [ ] **Minimum SDK**: Set to 26 (Android 8.0)
- [ ] **Target SDK**: Latest stable (34+)
- [ ] **App Icons**: Run `flutter pub run flutter_launcher_icons`

---

## 2. Signing & Security

### iOS
- [ ] Create iOS Distribution Certificate in Apple Developer Portal
- [ ] Create App Store Provisioning Profile
- [ ] Configure signing in Xcode (Signing & Capabilities)
- [ ] Enable App Groups if needed for widgets

### Android
- [ ] Generate release keystore:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- [ ] Create `android/key.properties`:
```properties
storePassword=your_password
keyPassword=your_password
keyAlias=upload
storeFile=../upload-keystore.jks
```
- [ ] Update `android/app/build.gradle.kts` to use release signing config
- [ ] Enable Google Play App Signing (recommended)

---

## 3. API Keys & Services

### Firebase
- [ ] Create production Firebase project
- [ ] Download and replace:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- [ ] Enable App Check in Firebase Console
- [ ] Configure Firebase Authentication methods
- [ ] Set up Firestore security rules for production

### Google Maps
- [ ] Create API key in Google Cloud Console
- [ ] Restrict key to your app's bundle ID/package name
- [ ] Add key to:
  - `android/app/src/main/res/values/strings.xml`
  - `ios/Runner/AppDelegate.swift` (GMSServices.provideAPIKey)

### Other Services
- [ ] Configure Cloudinary/S3 for production
- [ ] Set up production crash reporting (Firebase Crashlytics)
- [ ] Configure push notification certificates (APNS for iOS)

---

## 4. Privacy & Legal

### Required Documents
- [ ] **Privacy Policy URL**: Required for both stores
  - Host at: `https://majurun.app/privacy`
  - Include data collection, usage, third-party sharing info
- [ ] **Terms of Service URL**:
  - Host at: `https://majurun.app/terms`
- [ ] **Support URL**:
  - Host at: `https://majurun.app/support`
- [ ] **Contact Email**: Required for app store listings

### Data Collection Declarations
- [ ] iOS App Privacy Labels (App Store Connect):
  - Health & Fitness data
  - Location data
  - User content (posts, photos)
  - Identifiers
  - Usage data
- [ ] Google Play Data Safety Section:
  - Same categories as iOS
  - Include data retention policies

---

## 5. App Store Screenshots & Assets

### iOS (App Store)
- [ ] 6.7" (iPhone 15 Pro Max): 1290 x 2796 px
- [ ] 6.5" (iPhone 14 Plus): 1284 x 2778 px
- [ ] 5.5" (iPhone 8 Plus): 1242 x 2208 px
- [ ] 12.9" iPad Pro: 2048 x 2732 px
- [ ] App Preview Videos (optional): 15-30 seconds

### Google Play
- [ ] Phone screenshots: 1080 x 1920 px (min 2, max 8)
- [ ] 7" Tablet: 1200 x 1920 px
- [ ] 10" Tablet: 1600 x 2560 px
- [ ] Feature Graphic: 1024 x 500 px
- [ ] TV Banner (if applicable): 1280 x 720 px
- [ ] Promo Video: YouTube link (optional)

---

## 6. App Store Listing Content

### Both Platforms
- [ ] **App Name**: MajuRun (30 characters max for iOS)
- [ ] **Subtitle/Short Description**: "AI-Powered Running & Fitness" (30 chars iOS)
- [ ] **Description**:
  - Features list
  - Benefits
  - Call to action
  - 4000 characters max
- [ ] **Keywords** (iOS): Comma-separated, 100 chars total
- [ ] **Category**: Health & Fitness
- [ ] **Age Rating**: Configure content ratings questionnaire
- [ ] **Copyright**: "© 2026 Your Company Name"

---

## 7. Build & Release Commands

### iOS Build
```bash
# Clean and rebuild
flutter clean
flutter pub get

# Build iOS release
flutter build ios --release

# Archive in Xcode for App Store upload
# Or use Fastlane for automation
```

### Android Build
```bash
# Clean and rebuild
flutter clean
flutter pub get

# Build Android App Bundle (required for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 8. Testing Before Submission

### Functionality Tests
- [ ] User registration and login
- [ ] GPS tracking accuracy
- [ ] Run recording start/pause/stop
- [ ] Photo/video upload
- [ ] Push notifications
- [ ] In-app purchases (if applicable)
- [ ] Health data sync
- [ ] Offline functionality
- [ ] Background location tracking

### Device Testing
- [ ] Test on minimum supported iOS version
- [ ] Test on minimum supported Android version
- [ ] Test on various screen sizes
- [ ] Test on low-end devices
- [ ] Test battery consumption

### App Store Review Guidelines
- [ ] No placeholder content
- [ ] No broken links
- [ ] All permissions have clear usage descriptions
- [ ] No references to other platforms
- [ ] Login credentials for review team (if needed)

---

## 9. Common Rejection Reasons to Avoid

### iOS
- [ ] Missing purpose strings for permissions
- [ ] Crashes or bugs during review
- [ ] Login required without guest mode or demo account
- [ ] Links to external payment systems
- [ ] Incomplete metadata or screenshots

### Android
- [ ] Permission not used but declared
- [ ] Background location without proper disclosure
- [ ] Target SDK too low
- [ ] Missing privacy policy
- [ ] Crashes on specific devices

---

## 10. Post-Release

- [ ] Monitor crash reports (Firebase Crashlytics)
- [ ] Respond to user reviews
- [ ] Track analytics (Firebase Analytics)
- [ ] Plan version 1.1 updates based on feedback
- [ ] Set up staged rollout (Google Play)
- [ ] Enable phased release (iOS)

---

## Quick Commands Reference

```bash
# Generate icons
flutter pub run flutter_launcher_icons

# Analyze code
flutter analyze

# Run tests
flutter test

# Build release APK
flutter build apk --release

# Build release App Bundle
flutter build appbundle --release

# Build iOS
flutter build ios --release

# Get dependencies
flutter pub get

# Clean build
flutter clean
```

---

## Support & Resources

- [Flutter Deployment Guide](https://docs.flutter.dev/deployment)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policy Center](https://play.google.com/console/about/policy-center/)
- [Firebase Documentation](https://firebase.google.com/docs)

---

**Last Updated**: February 2026
