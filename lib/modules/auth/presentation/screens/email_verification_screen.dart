import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/auth_wrapper.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (_) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet — please check your inbox.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _resending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification(
        ActionCodeSettings(
          url: 'https://majurun-8d8b5.firebaseapp.com',
          handleCodeInApp: false,
          iOSBundleId: 'com.majurun.app',
          androidPackageName: 'com.majurun.app',
          androidInstallApp: true,
          androidMinimumVersion: '21',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification email sent to $_email'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _resendCooldown = 60);
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) t.cancel();
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: .12),
                  cs.secondary.withValues(alpha: .10),
                  cs.surfaceTint.withValues(alpha: .08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
              top: -60, right: -60,
              child: _Blob(color: cs.primary.withValues(alpha: .20), size: 200)),
          Positioned(
              bottom: -40, left: -40,
              child: _Blob(color: cs.secondary.withValues(alpha: .16), size: 160)),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cs.outline.withValues(alpha: .12)),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: .12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.mark_email_unread_rounded,
                                  size: 48, color: cs.primary),
                            ),
                            const SizedBox(height: 20),

                            Text('Verify your email',
                                style: text.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),

                            Text(
                              'We sent a verification link to',
                              style: text.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _email,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Open your inbox, click the link, then tap the button below to continue.',
                              style: text.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 32),

                            // Primary CTA
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _checking ? null : _checkVerification,
                                icon: _checking
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_circle_outline_rounded),
                                label: const Text("I've verified my email",
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Resend
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: (_resending || _resendCooldown > 0)
                                    ? null
                                    : _resendEmail,
                                icon: _resending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.refresh_rounded),
                                label: Text(
                                  _resendCooldown > 0
                                      ? 'Resend in ${_resendCooldown}s'
                                      : 'Resend verification email',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                            Divider(color: cs.outline.withValues(alpha: .3)),
                            const SizedBox(height: 8),

                            TextButton.icon(
                              onPressed: _signOut,
                              icon: Icon(Icons.logout_rounded,
                                  size: 18, color: cs.onSurfaceVariant),
                              label: Text('Use a different account',
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: .6), blurRadius: 60, spreadRadius: 10)
          ],
        ),
      );
}
