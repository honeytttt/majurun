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

class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Logo scales in with elastic bounce, then pulses
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_ctrl);

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // After landing, gentle breathing pulse
    _pulse = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.04)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 23,
      ),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => FadeTransition(
            opacity: _fade,
            child: Transform.scale(
              scale: _scale.value * _pulse.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/majurun-logo.jpg',
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _FallbackLogo(
                        scale: _scale.value * _pulse.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C853),
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  final double scale;
  const _FallbackLogo({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6 * scale,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF00C853), Color(0xFF00796B)],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'MAJURUN',
            style: TextStyle(
              color: Color(0xFF00C853),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}
