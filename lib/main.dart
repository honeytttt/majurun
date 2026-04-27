import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Core services - Use ServiceLocator for singleton access
import 'core/services/analytics_service.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/services/service_locator.dart';
import 'core/services/sentry_service.dart';
import 'core/config/app_config.dart';

// Theme
import 'core/theme/app_theme.dart';
// Repos
import 'modules/auth/domain/repositories/auth_repository.dart';
import 'modules/auth/data/repositories/firebase_auth_impl.dart';
// Training
import 'modules/training/services/training_service.dart';
// Run module - RunController now manages its own dependencies
import 'modules/run/controllers/run_controller.dart';
// Wrapper
import 'modules/auth/presentation/widgets/auth_wrapper.dart';
// Counter initializer
import 'core/utils/user_counters_initializer.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/health_sync_service.dart';
import 'modules/engagement/engagement_service.dart';
import 'core/services/remote_logger.dart';
import 'core/services/cache_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

Future<void> _configureAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    // iOS: playback + duckOthers — music lowers while TTS speaks, restores after.
    // NOT ambient: ambient silences TTS when screen locks (breaks run announcements).
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    // Android: request transient focus with ducking so music lowers, not pauses.
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      usage: AndroidAudioUsage.assistanceNavigationGuidance,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
  ));
}

Future<void> main() async {
  // Wrap entire app initialization with Sentry for comprehensive error tracking
  await SentryService.initializeApp(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Increase Flutter's image memory cache from 100 MB (default) to 250 MB.
    // With 30-40 feed posts each carrying an avatar + post image, the default
    // fills quickly and starts evicting images — causing loading spinners to
    // reappear when scrolling back up.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 250 * 1024 * 1024;

    // Initialize timezone data so scheduled notifications fire at the correct
    // LOCAL time. Without this, tz.local defaults to UTC which causes reminders
    // to fire at wrong times (e.g. 7:30 UTC = 3:30 PM in Malaysia UTC+8).
    tz_data.initializeTimeZones();
    // Use device's UTC offset to pick the closest named timezone.
    // This avoids requiring the flutter_timezone package while still handling
    // the most common case correctly.
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final offsetHours = offsetMinutes / 60;
    String timezoneName = 'UTC';
    if (offsetHours >= 7.5 && offsetHours < 9) {
      timezoneName = 'Asia/Kuala_Lumpur'; // UTC+8 (Malaysia, Singapore)
    } else if (offsetHours >= 5.5 && offsetHours < 6) {
      timezoneName = 'Asia/Kolkata'; // UTC+5:30
    } else if (offsetHours >= 7 && offsetHours < 8) {
      timezoneName = 'Asia/Bangkok'; // UTC+7
    } else if (offsetHours >= 8 && offsetHours < 9) {
      timezoneName = 'Asia/Shanghai'; // UTC+8 exact
    } else if (offsetHours >= 9 && offsetHours < 10) {
      timezoneName = 'Asia/Tokyo'; // UTC+9
    } else if (offsetHours > 0) {
      // Generic positive offset zones
      timezoneName = 'Etc/GMT-${offsetHours.round()}';
    } else if (offsetHours < 0) {
      timezoneName = 'Etc/GMT+${(-offsetHours).round()}';
    }
    try {
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Fallback: keep UTC if location lookup fails
    }

    // Configure audio session: TTS ducks music while speaking, restores after.
    // audio_session manages setActive(true/false) lifecycle properly — this is
    // what was missing in previous builds (music never restored after ducking).
    await _configureAudioSession();

    // Initialize local cache service for offline mode
    await CacheService().initialize();

    // Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) rethrow;
    }

    // Offline persistence — feed and profile load instantly on relaunch
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Firebase App Check — run async after runApp() so it doesn't block the first frame.
    // App Attest on iOS can take 3–5 seconds on first launch; there's no UX benefit
    // to blocking startup for it — requests made before it completes still work.
    Future(() => FirebaseAppCheck.instance.activate(
      androidProvider: AppConfig.isProduction
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      appleProvider: AppConfig.isProduction
          ? AppleProvider.appAttestWithDeviceCheckFallback
          : AppleProvider.debug,
    ));

    // Attach remote logger — WARNING+ logs → Firestore app_logs
    RemoteLogger.attach();

    // Initialize ServiceLocator (handles all core services)
    await serviceLocator.initialize();

    // Get service instances from ServiceLocator
    final crashReporting = serviceLocator.crashReportingService;
    final analytics = serviceLocator.analyticsService;

    // Setup global error handling
    crashReporting.setupGlobalErrorHandling();

    // Replace the default red debug banner with a minimal fallback widget.
    // In production users never see a crash dump — they see a friendly message.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (kDebugMode) return ErrorWidget(details.exception);
      return _AppErrorFallback(error: details.exception.toString());
    };

    runApp(
      MultiProvider(
        providers: [
          Provider<AuthRepository>(create: (_) => FirebaseAuthImpl()),
          ChangeNotifierProvider<TrainingService>(create: (_) => TrainingService()),
          // RunController now creates and manages all run-related controllers internally
          ChangeNotifierProvider<RunController>(create: (_) => RunController()),
          Provider<AnalyticsService>.value(value: analytics),
          Provider<CrashReportingService>.value(value: crashReporting),
        ],
        child: const MyApp(),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAuthListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-schedule notifications every time the app comes back to foreground.
    // Android cancels AlarmManager alarms on app update or device restart, so
    // rescheduling on resume ensures daily notifications survive both events.
    if (state == AppLifecycleState.resumed) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        PushNotificationService().scheduleDefaultNotifications();
        EngagementService.maybeRun(user.uid); // engagement addons — isolated
      }
    }
  }

  void _setupAuthListener() {
    // Use singleton instances from ServiceLocator - NOT new instances
    final analytics = serviceLocator.analyticsService;
    final crashReporting = serviceLocator.crashReportingService;
    final sentry = serviceLocator.sentryService;

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        UserCountersInitializer.initializeOnFirstLaunch();
        // Initialize notifications + schedule default daily notifications
        PushNotificationService().initialize().then((_) {
          PushNotificationService().scheduleDefaultNotifications();
          EngagementService.maybeRun(user.uid); // engagement addons — isolated
        });
        // Auto-sync run history from health apps on first install (silent)
        HealthSyncService().autoSyncOnFirstInstall();
        // Set user ID for analytics, crash reporting, and Sentry
        analytics.setUserId(user.uid);
        crashReporting.setUserId(user.uid);
        sentry.setUser(user);
      } else {
        // Clear user ID when logged out
        analytics.setUserId(null);
        crashReporting.clearUserId();
        sentry.clearUser();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Majurun',
      debugShowCheckedModeBanner: false,
      // Use premium dark theme for professional look
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AuthWrapper(),
    );
  }
}

/// Minimal production error fallback shown instead of the red debug banner.
class _AppErrorFallback extends StatelessWidget {
  const _AppErrorFallback({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFF0D0D0D),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 56, color: Color(0xFF7ED957)),
                SizedBox(height: 20),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your run data is safe. Please restart the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}