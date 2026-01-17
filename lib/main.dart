import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Repositories
import 'package:majurun/modules/auth/data/repositories/firebase_auth_repository.dart';
import 'package:majurun/modules/workout/domain/repositories/workout_repository.dart';
import 'package:majurun/modules/workout/data/repositories/firebase_workout_repository.dart';
import 'package:majurun/modules/profile/domain/repositories/profile_repository.dart';
import 'package:majurun/modules/profile/data/repositories/firebase_profile_repository.dart';

// Screens
import 'package:majurun/modules/auth/presentation/screens/login_screen.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Note: .env not found.");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseAuthRepository>(create: (_) => FirebaseAuthRepository()),
        Provider<WorkoutRepository>(create: (_) => FirebaseWorkoutRepository()),
        Provider<ProfileRepository>(create: (_) => FirebaseProfileRepository()),
      ],
      child: MaterialApp(
        title: 'Majurun',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepo = context.watch<FirebaseAuthRepository>();
    return StreamBuilder<User?>(
      stream: authRepo.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen(); // Your restored blueprint screen
        }
        return const LoginScreen();
      },
    );
  }
}