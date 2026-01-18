import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../screens/login_screen.dart';

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

        // 2. If user exists, show the main App/Home
        if (snapshot.hasData && snapshot.data != null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Majurun"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => authRepository.signOut(),
                )
              ],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Welcome, ${snapshot.data!.email}"),
                  if (snapshot.data!.isGuest) 
                    const Text("(Guest Mode)", style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          );
        }

        // 3. If no user, show the Login Screen
        return const LoginScreen();
      },
    );
  }
}