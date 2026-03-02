// App Constants & Configuration
// Location: lib/core/utils/app_constants.dart
// Created: 2026-02-27
// -----------------------------------------------------------------------
// Centralized configuration for the app
// Move sensitive keys to environment variables for production
// -----------------------------------------------------------------------

import 'package:flutter/foundation.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'MajuRun';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;

  // Bundle IDs
  static const String iosBundleId = 'com.majurun.app';
  static const String androidPackage = 'com.majurun.app';

  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enableCrashReporting = !kDebugMode;
  static const bool enableAnalytics = !kDebugMode;

  // Run Tracking
  static const int locationUpdateIntervalMs = 1000; // 1 second
  static const int autoSaveIntervalSeconds = 30; // Save every 30 seconds
  static const double minGpsAccuracyMeters = 30.0; // Reject inaccurate GPS points
  static const double minDistanceFilterMeters = 5.0; // Minimum movement to record
  static const int idleTimeoutMinutes = 10; // Auto-pause after 10 min idle

  // Workout
  static const int defaultRestDurationSeconds = 15;
  static const int workoutAutoSaveIntervalSeconds = 60;

  // Social/Feed
  static const int feedPageSize = 20;
  static const int maxPostsPerDay = 10;
  static const int maxCommentLength = 500;
  static const int maxBioLength = 150;

  // Timeouts
  static const int networkTimeoutSeconds = 30;
  static const int locationTimeoutSeconds = 15;

  // Cache
  static const int imageCacheDays = 7;
  static const int maxCachedImages = 100;

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String runsCollection = 'runs';
  static const String postsCollection = 'posts';
  static const String conversationsCollection = 'conversations';
  static const String notificationsCollection = 'notifications';

  // URLs
  static const String privacyPolicyUrl = 'https://www.majurun.com/privacy-policy.html';
  static const String termsOfServiceUrl = 'https://www.majurun.com/terms-of-service.html';
  static const String supportEmail = 'admin@majurun.com';
  static const String websiteUrl = 'https://www.majurun.com';
}

/// Validation constants
class ValidationConstants {
  ValidationConstants._();

  // Password
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const String passwordPattern = r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$';

  // Username
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;
  static const String usernamePattern = r'^[a-zA-Z0-9_]+$';

  // Run data
  static const double maxRunDistanceKm = 500; // Max 500km single run
  static const int maxRunDurationHours = 48; // Max 48 hours
  static const double minPaceMinPerKm = 1.5; // World record pace
  static const double maxPaceMinPerKm = 30.0; // Very slow walking
}

/// Error messages
class ErrorMessages {
  ErrorMessages._();

  static const String networkError = 'Unable to connect. Please check your internet connection.';
  static const String locationPermissionDenied = 'Location permission is required for run tracking.';
  static const String locationServiceDisabled = 'Please enable location services to track your run.';
  static const String gpsSignalWeak = 'GPS signal is weak. Try moving to an open area.';
  static const String saveFailed = 'Failed to save. Your data will be saved when connection is restored.';
  static const String authFailed = 'Authentication failed. Please try again.';
  static const String unknownError = 'Something went wrong. Please try again.';
  static const String sessionExpired = 'Your session has expired. Please log in again.';
}

/// Accessibility labels
class A11yLabels {
  A11yLabels._();

  // Run tracking
  static const String startRunButton = 'Start run';
  static const String pauseRunButton = 'Pause run';
  static const String resumeRunButton = 'Resume run';
  static const String stopRunButton = 'Stop and save run';
  static const String currentDistance = 'Current distance';
  static const String currentPace = 'Current pace';
  static const String elapsedTime = 'Elapsed time';
  static const String runMap = 'Map showing your run route';

  // Navigation
  static const String homeTab = 'Home feed';
  static const String workoutsTab = 'Workouts';
  static const String runTab = 'Run tracking';
  static const String rewardsTab = 'Rewards and achievements';
  static const String profileTab = 'Your profile';

  // Common
  static const String closeButton = 'Close';
  static const String backButton = 'Go back';
  static const String menuButton = 'Open menu';
  static const String settingsButton = 'Open settings';
  static const String refreshButton = 'Refresh';
  static const String searchField = 'Search';
}
