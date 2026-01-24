import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:majurun/firebase_options.dart'; 

// REPOS & ENTITIES
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/auth/data/repositories/firebase_auth_impl.dart';

// TRAINING MODULE
import 'package:majurun/modules/training/services/training_service.dart';

// RUN MODULE (FIX: Added this import to resolve the ProviderNotFoundException)
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
        // Existing Auth Repository
        Provider<AuthRepository>(
          create: (_) => FirebaseAuthImpl(),
        ),
        
        // NEW: Training Service for automated voice coaching
        ChangeNotifierProvider<TrainingService>(
          create: (_) => TrainingService(),
        ),

        // FIX: Added RunController here. 
        // This makes it available to RunTrackerScreen, RunSummaryScreen, and RunHistoryScreen.
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(), 
    );
  }
}