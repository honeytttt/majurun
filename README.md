# MajuRun 🏃‍♂️

A production-grade, modular running application built with Flutter and Firebase. MajuRun offers comprehensive run tracking, training plans, social engagement, and offline capabilities.

## 🚀 Features

- **Real-time Run Tracking:** High-precision GPS tracking with auto-pause, voice announcements, and live performance metrics.
- **Modular Architecture:** Cleanly separated modules (Auth, Run, Training, Social, Profile) for maximum maintainability.
- **Voice Coaching:** Integrated TTS (Text-to-Speech) for real-time training guidance and milestone announcements.
- **Offline First:** Robust offline support using Hive and Sqflite with background synchronization.
- **Training Plans:** Structured plans (C25K, 10K, Marathon) with progress tracking.
- **Social Integration:** Feed, followers, likes, and achievement sharing.
- **Security:** Custom Firebase Claims for admin management and granular Firestore security rules.

## 🛠 Tech Stack

- **Frontend:** Flutter (State: Provider, DI: ServiceLocator)
- **Backend:** Firebase (Auth, Firestore, Analytics, Crashlytics, Performance, App Check)
- **Monitoring:** Sentry & Firebase Crashlytics
- **Analytics:** Firebase Analytics with custom event tracking
- **CI/CD:** GitHub Actions (Automated testing, linting, and build distribution)

## 📦 Getting Started

### Prerequisites
- Flutter SDK (>= 3.3.0)
- Firebase Project
- Google Maps API Key

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/majurun.git
   cd majurun
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Run `flutterfire configure`
   - Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in their respective directories.

4. Run the app:
   ```bash
   flutter run
   ```

## 🧪 Testing

We prioritize stability. Run the test suite:
```bash
flutter test
```

## 📜 Architecture

MajuRun follows a modular feature-based architecture:
- `lib/core`: Cross-cutting concerns (services, theme, utils, constants).
- `lib/modules`: Independent feature modules containing their own domain, data, and presentation layers.
- `lib/env`: Environment-specific configurations.

## 🛡 Security

- Admin privileges are managed via Firebase Custom Claims (`admin: true`).
- Input validation is strictly enforced via `InputValidators`.
- App Check protects backend resources from unauthorized traffic.
