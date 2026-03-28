import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/repositories/auth_repository.dart';
import 'signup_screen.dart';

const String kTermsAndConditionsUrl = 'https://www.majurun.com/terms-and-conditions.html';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _openTermsAndConditions() async {
    final uri = Uri.parse(kTermsAndConditionsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Terms and Conditions')),
        );
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows a professional bottom sheet when password is wrong
  void _showWrongCredentialsSheet(String email) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CredentialErrorSheet(
        email: email,
        onResetPassword: () {
          Navigator.pop(ctx);
          _showForgotPasswordSheet(prefillEmail: email);
        },
      ),
    );
  }

  /// Shows forgot password bottom sheet
  void _showForgotPasswordSheet({String prefillEmail = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordSheet(prefillEmail: prefillEmail),
    );
  }

  /// Email sign-in with smart error handling
  Future<void> _handleEmailSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    final authRepo = context.read<AuthRepository>();
    try {
      await authRepo.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString().toLowerCase();
      if (msg.contains('wrong-password') ||
          msg.contains('invalid-credential') ||
          msg.contains('invalid credential') ||
          msg.contains('password is invalid') ||
          msg.contains('incorrect password')) {
        _showWrongCredentialsSheet(_emailController.text.trim());
      } else if (msg.contains('user-not-found') ||
          msg.contains('no user record') ||
          msg.contains('no account')) {
        _showNoAccountDialog();
      } else {
        _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showNoAccountDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.person_search_rounded, color: cs.primary),
            const SizedBox(width: 10),
            const Text('Account not found'),
          ],
        ),
        content: Text(
          'No account exists for this email address.\nWould you like to create a new account?',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              );
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSocialAuth(Future<void> Function() authMethod) async {
    setState(() => _isLoading = true);
    try {
      await authMethod();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authRepo = context.read<AuthRepository>();

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background matching signup screen
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: .10),
                  cs.secondary.withValues(alpha: .08),
                  cs.surfaceTint.withValues(alpha: .06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative blobs
          Positioned(
            top: -80,
            left: -60,
            child: _Blob(color: cs.primary.withValues(alpha: .18), size: 220),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: _Blob(color: cs.secondary.withValues(alpha: .14), size: 180),
          ),

          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: .80),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cs.outline.withValues(alpha: .12)),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: SingleChildScrollView(
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
                                height: 90,
                                width: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.directions_run_rounded,
                                  size: 60,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome back',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to continue your journey',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 28),

                            // Email field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined, color: cs.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                            ),
                            const SizedBox(height: 14),

                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleEmailSignIn(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline, color: cs.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Password is required' : null,
                            ),

                            // Forgot password link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _showForgotPasswordSheet(
                                    prefillEmail: _emailController.text.trim()),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _handleEmailSignIn,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(color: cs.outline.withValues(alpha: .4))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(color: cs.outline.withValues(alpha: .4))),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Social logins — Google + Twitter (X) only
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SocialButton(
                                  label: 'Google',
                                  icon: Icons.g_mobiledata_rounded,
                                  iconColor: Colors.red.shade600,
                                  onTap: _isLoading
                                      ? null
                                      : () => _handleSocialAuth(authRepo.signInWithGoogle),
                                ),
                                const SizedBox(width: 16),
                                _SocialButton(
                                  label: 'Twitter / X',
                                  iconWidget: const FaIcon(
                                    FontAwesomeIcons.xTwitter,
                                    size: 20,
                                    color: Colors.black,
                                  ),
                                  onTap: _isLoading
                                      ? null
                                      : () => _handleSocialAuth(authRepo.signInWithTwitter),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Terms
                            Text.rich(
                              TextSpan(
                                text: 'By signing in, you agree to our ',
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
                                      ..onTap = _openTermsAndConditions,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 20),

                            // Sign up link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account?",
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                                  ),
                                  child: Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ─── Decorative blob ───────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .5), blurRadius: 60, spreadRadius: 10),
        ],
      ),
    );
  }
}

// ─── Social login button ───────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Widget? iconWidget;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    this.icon,
    this.iconColor,
    this.iconWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(12),
          color: cs.surface.withValues(alpha: .6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconWidget != null)
              iconWidget!
            else
              Icon(icon!, color: iconColor, size: 26),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Wrong credentials bottom sheet ───────────────────────────────────────────
class _CredentialErrorSheet extends StatelessWidget {
  final String email;
  final VoidCallback onResetPassword;

  const _CredentialErrorSheet({required this.email, required this.onResetPassword});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_reset_rounded, color: Colors.orange.shade700, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Incorrect Password',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'The password for $email is incorrect.\nWould you like to reset it?',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onResetPassword,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Reset Password via Email'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Forgot password bottom sheet ─────────────────────────────────────────────
class _ForgotPasswordSheet extends StatefulWidget {
  final String prefillEmail;
  const _ForgotPasswordSheet({this.prefillEmail = ''});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _emailCtrl;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.prefillEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.sendPasswordResetEmail(email);
      if (mounted) setState(() { _sending = false; _sent = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            if (_sent) ...[
              Icon(Icons.mark_email_read_rounded, color: cs.primary, size: 48),
              const SizedBox(height: 16),
              Text(
                'Reset email sent!',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your inbox at\n${_emailCtrl.text.trim()}\n\nClick the link in the email to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.6),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ] else ...[
              Icon(Icons.lock_reset_rounded, color: cs.primary, size: 40),
              const SizedBox(height: 16),
              Text(
                'Reset Password',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your account email and we'll send a reset link.",
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: widget.prefillEmail.isEmpty,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _sendReset,
                  icon: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Sending...' : 'Send Reset Link'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
