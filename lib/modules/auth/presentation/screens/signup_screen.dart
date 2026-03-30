import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:majurun/modules/auth/presentation/screens/onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  double _passwordScore(String v) {
    double s = 0;
    if (v.length >= 8) s += .25;
    if (RegExp(r'[A-Z]').hasMatch(v)) s += .25;
    if (RegExp(r'[0-9]').hasMatch(v)) s += .25;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s += .25;
    return s.clamp(0, 1);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthRepository>().signUpWithEmail(
            email: _email.text.trim(),
            password: _password.text.trim(),
          );
      // Navigate explicitly — AuthWrapper rebuilds underneath but doesn't pop the navigator stack
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('already registered') || msg.contains('already-in-use')) {
        _showAlreadyExistsDialog(_email.text.trim());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAlreadyExistsDialog(String email) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.person_search_rounded, color: cs.primary),
          const SizedBox(width: 10),
          const Text('Account exists'),
        ]),
        content: Text(
          'An account already exists for\n$email\n\nPlease sign in instead. If you forgot your password, use "Forgot password?" on the sign-in screen.',
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);      // close dialog
              Navigator.pop(context);  // back to LoginScreen
            },
            child: const Text('Go to Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogle() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthRepository>().signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          Positioned(top: -60, right: -60,
            child: _Blob(color: cs.primary.withValues(alpha: .20), size: 200)),
          Positioned(bottom: -40, left: -40,
            child: _Blob(color: cs.secondary.withValues(alpha: .16), size: 160)),

          Center(
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
                        color: cs.surface.withValues(alpha: .80),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cs.outline.withValues(alpha: .12)),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/majurun-logo.jpg',
                                height: 80, width: 80, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.directions_run_rounded, size: 60, color: cs.primary),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Create your account',
                                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('Join MajuRun — it takes 30 seconds',
                                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 28),

                            // Google Sign-In (primary CTA)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _handleGoogle,
                                icon: _loading
                                    ? const SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const FaIcon(FontAwesomeIcons.google,
                                        size: 20, color: Colors.red),
                                label: const Text('Continue with Google',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(child: Divider(color: cs.outline.withValues(alpha: .4))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                              ),
                              Expanded(child: Divider(color: cs.outline.withValues(alpha: .4))),
                            ]),
                            const SizedBox(height: 20),

                            // Email
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined, color: cs.primary),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Email is required';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password with strength
                            StatefulBuilder(
                              builder: (ctx, setInner) {
                                final score = _passwordScore(_password.text);
                                final color = score < .5
                                    ? Colors.red.shade400
                                    : score < .75
                                        ? Colors.orange.shade600
                                        : cs.primary;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _password,
                                      obscureText: _obscure,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      onChanged: (_) => setInner(() {}),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: Icon(Icons.lock_outline, color: cs.primary),
                                        suffixIcon: IconButton(
                                          icon: Icon(_obscure
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded),
                                          onPressed: () => setState(() => _obscure = !_obscure),
                                        ),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                      validator: (v) => (v == null || v.length < 8)
                                          ? 'Use at least 8 characters'
                                          : null,
                                    ),
                                    if (_password.text.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: score,
                                          minHeight: 4,
                                          color: color,
                                          backgroundColor: cs.surfaceContainerHighest,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        score < .5 ? 'Weak' : score < .75 ? 'Medium' : 'Strong',
                                        style: text.bodySmall?.copyWith(color: color),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Create Account button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _loading ? null : _submit,
                                icon: _loading
                                    ? const SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.person_add_rounded),
                                label: const Text('Create Account',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            Text.rich(
                              TextSpan(
                                text: 'By continuing, you agree to our ',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: cs.primary,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        final uri = Uri.parse(
                                            'https://www.majurun.com/terms-and-conditions.html');
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode.externalApplication);
                                        }
                                      },
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Already have an account?',
                                    style: TextStyle(color: cs.onSurfaceVariant)),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Sign In',
                                      style: TextStyle(
                                          color: cs.primary, fontWeight: FontWeight.bold)),
                                ),
                              ],
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
        width: size, height: size,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: .6), blurRadius: 60, spreadRadius: 10)],
        ),
      );
}
