import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/auth/domain/entities/app_user.dart';
import 'package:majurun/modules/auth/presentation/screens/email_verification_screen.dart';
import 'package:majurun/modules/auth/presentation/screens/login_screen.dart';
import 'package:majurun/modules/auth/presentation/screens/onboarding_screen.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = context.watch<AuthRepository>();

    return StreamBuilder<AppUser?>(
      stream: authRepository.onAuthStateChanged,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        // For email/password accounts, require email verification before proceeding.
        // Social sign-ins (Google, Twitter) are verified by the provider — skip this check.
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final isEmailPasswordProvider = firebaseUser?.providerData.any(
              (info) => info.providerId == 'password',
            ) ??
            false;
        if (isEmailPasswordProvider && !(firebaseUser?.emailVerified ?? false)) {
          return const EmailVerificationScreen();
        }

        // User is authenticated — check if onboarding profile is complete
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Admin always goes straight to HomeScreen regardless of profile completion
            if (user.email == 'majurun.app@gmail.com') return const HomeScreen();

            final data = profileSnap.data?.data() as Map<String, dynamic>?;
            final hasProfile = data != null && data['dob'] != null;

            return hasProfile ? const HomeScreen() : const OnboardingScreen();
          },
        );
      },
    );
  }
}
