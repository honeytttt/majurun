import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/auth/domain/entities/app_user.dart';
import 'package:majurun/modules/auth/presentation/screens/login_screen.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // We watch the repository to get the auth state stream
    final authRepository = context.watch<AuthRepository>();

    return StreamBuilder<AppUser?>(
      stream: authRepository.onAuthStateChanged,
      builder: (context, snapshot) {
        // 1. Show loading while checking connection
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If user exists, show the Blueprint Home Screen
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // 3. If no user, show the Login Screen (LOCKED 100%)
        return const LoginScreen();
      },
    );
  }
}