import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/firebase_options.dart';

// Interfaces
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/profile/domain/repositories/profile_repository.dart';
import 'package:majurun/modules/workout/domain/repositories/workout_repository.dart';

// Implementations
import 'package:majurun/modules/auth/data/repositories/firebase_auth_repository.dart';
import 'package:majurun/modules/profile/data/repositories/firebase_profile_repository.dart';
import 'package:majurun/modules/workout/data/repositories/firebase_workout_repository.dart';

import 'package:majurun/modules/auth/presentation/screens/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        // 1. Auth Provider
        Provider<AuthRepository>(
          create: (_) => FirebaseAuthRepository(),
        ),
        // 2. Profile Provider (This was likely missing or incorrectly typed)
        Provider<ProfileRepository>(
          create: (_) => FirebaseProfileRepository(),
        ),
        // 3. Workout Provider
        Provider<WorkoutRepository>(
          create: (_) => FirebaseWorkoutRepository(),
        ),
      ],
      child: const MajuRunApp(),
    ),
  );
}

class MajuRunApp extends StatelessWidget {
  const MajuRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MajuRun',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}