import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
// App Check
import 'package:firebase_app_check/firebase_app_check.dart';

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
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaEnterpriseProvider(
      '6LfJE2gsAAAAAP2xeAzsC95tz7jAzim7wAjtarF0', // your Enterprise site key
    ),
    // If you enforce App Check on mobile later, you can add providers here:
    // androidProvider: AndroidProvider.playIntegrity,
    // appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
  );

  // Initialize user counters on first launch (non-blocking)
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      UserCountersInitializer.initializeOnFirstLaunch();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>(create: (_) => FirebaseAuthImpl()),
        ChangeNotifierProvider<TrainingService>(create: (_) => TrainingService()),
        // RunController now creates and manages all run-related controllers internally
        ChangeNotifierProvider<RunController>(create: (_) => RunController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
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