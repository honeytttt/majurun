import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:majurun/modules/home/presentation/screens/main_nav_screen.dart';
import 'package:majurun/modules/auth/presentation/screens/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has data, the user is logged in
        if (snapshot.hasData) {
          return const MainNavScreen();
        }
        // Otherwise, show the Login Screen
        return const LoginScreen();
      },
    );
  }
}