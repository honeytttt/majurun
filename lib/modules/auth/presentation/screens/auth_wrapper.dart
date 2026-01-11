import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/auth_repository.dart';
import 'login_screen.dart';
import '../../../home/presentation/screens/main_nav_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    final authRepo = Provider.of<AuthRepository>(context);

    return StreamBuilder<User?>(
      stream: authRepo.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // Success State: Redirect to Main Navigation
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavScreen();
        }

        // Default State: Show Login
        return const LoginScreen();
      },
    );
  }
}