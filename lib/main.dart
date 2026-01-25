import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:majurun/firebase_options.dart';

// THEME
import 'package:majurun/core/theme/app_theme.dart';

// REPOS & ENTITIES
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/auth/data/repositories/firebase_auth_impl.dart';

// TRAINING MODULE
import 'package:majurun/modules/training/services/training_service.dart';

// RUN MODULE
import 'package:majurun/modules/run/controllers/run_controller.dart';

// WRAPPER
import 'package:majurun/modules/auth/presentation/widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) => FirebaseAuthImpl(),
        ),
        ChangeNotifierProvider<TrainingService>(
          create: (_) => TrainingService(),
        ),
        ChangeNotifierProvider<RunController>(
          create: (_) => RunController(),
        ),
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
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}
