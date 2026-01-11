import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

// 1. Import the generated options file
import 'firebase_options.dart'; 

// Core & Modules
import 'core/theme/app_theme.dart';
import 'modules/auth/domain/repositories/auth_repository.dart';
import 'modules/auth/data/repositories/firebase_auth_repository.dart';
import 'modules/auth/presentation/screens/auth_wrapper.dart';
import 'modules/profile/domain/repositories/profile_repository.dart';
import 'modules/profile/data/repositories/firebase_profile_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Use the automatic configuration
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) => FirebaseAuthRepository(),
        ),
        Provider<ProfileRepository>(
          create: (_) => FirebaseProfileRepository(),
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
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}