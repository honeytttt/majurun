import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}