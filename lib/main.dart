import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
// App Check
import 'package:firebase_app_check/firebase_app_check.dart';

// Core services
import 'core/services/analytics_service.dart';
import 'core/services/crash_reporting_service.dart';
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
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check BEFORE using any protected Firebase APIs
  // Web: Use reCAPTCHA Enterprise provider with your site key
  // Configure via: flutter build --dart-define=RECAPTCHA_KEY=your_key
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaEnterpriseProvider(AppConfig.recaptchaSiteKey),
    // Android: Use Play Integrity for production
    androidProvider: AndroidProvider.playIntegrity,
    // iOS: Use App Attest with Device Check fallback
    appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
  );

  // Initialize crash reporting (must be before other services)
  final crashReporting = CrashReportingService();
  try {
    await crashReporting.initialize();
    crashReporting.setupGlobalErrorHandling();
  } catch (e) {
    debugPrint('CrashReporting initialization failed: $e');
  }

  // Initialize analytics
  final analytics = AnalyticsService();
  try {
    await analytics.initialize();
  } catch (e) {
    debugPrint('Analytics initialization failed: $e');
  }

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
    final analytics = AnalyticsService();
    final crashReporting = CrashReportingService();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        UserCountersInitializer.initializeOnFirstLaunch();
        // Set user ID for analytics and crash reporting
        analytics.setUserId(user.uid);
        crashReporting.setUserId(user.uid);
      } else {
        // Clear user ID when logged out
        analytics.setUserId(null);
        crashReporting.clearUserId();
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