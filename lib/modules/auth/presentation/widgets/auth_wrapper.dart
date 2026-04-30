import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/auth/domain/entities/app_user.dart';
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
          return const _LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        // Admin check: supports both modern Custom Claims and legacy email fallback.
        // This ensures zero downtime for the existing admin while enabling claim-based security.
        return FutureBuilder<IdTokenResult>(
          future: FirebaseAuth.instance.currentUser!.getIdTokenResult(),
          builder: (context, tokenSnap) {
            // While checking token, show a loader to prevent premature redirection to Onboarding
            if (tokenSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final isAdmin = (tokenSnap.data?.claims?['admin'] == true) || 
                            (user.email == 'majurun.app@gmail.com');
            
            if (isAdmin) return const HomeScreen();

            // Regular User Flow
            // Use snapshots() NOT get() — avoids the FutureBuilder reset problem.
            return StreamBuilder<DocumentSnapshot>(
              key: ValueKey(user.uid),
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, profileSnap) {
                if (profileSnap.connectionState == ConnectionState.waiting) {
                  return const _LoadingScreen();
                }

                final data = profileSnap.data?.data() as Map<String, dynamic>?;
                final hasProfile = data != null && data['dob'] != null;

                return hasProfile ? const HomeScreen() : const OnboardingScreen();
              },
            );
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
    );
  }
}
