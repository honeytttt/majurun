import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
// App Check - DISABLED for iOS build compatibility
// import 'package:firebase_app_check/firebase_app_check.dart';

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

Future<void> main() async {
  // Wrap entire app initialization with Sentry for comprehensive error tracking
  await SentryService.initializeApp(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase - handle duplicate-app error gracefully
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Firebase already initialized by native code, ignore
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }

    // Firebase App Check - DISABLED for testing
    // TODO: Re-enable for production with proper Play Integrity setup
    // await FirebaseAppCheck.instance.activate(
    //   webProvider: ReCaptchaEnterpriseProvider(AppConfig.recaptchaSiteKey),
    //   androidProvider: AndroidProvider.playIntegrity,
    //   appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
    // );

    // Initialize ServiceLocator (handles all core services)
    await serviceLocator.initialize();

    // Get service instances from ServiceLocator
    final crashReporting = serviceLocator.crashReportingService;
    final analytics = serviceLocator.analyticsService;

    // Setup global error handling
    crashReporting.setupGlobalErrorHandling();

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

class _MyAppState extends State<MyApp> {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    // Use singleton instances from ServiceLocator - NOT new instances
    final analytics = serviceLocator.analyticsService;
    final crashReporting = serviceLocator.crashReportingService;
    final sentry = serviceLocator.sentryService;

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        UserCountersInitializer.initializeOnFirstLaunch();
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