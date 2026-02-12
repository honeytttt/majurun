// lib/modules/auth/presentation/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ✅ relative import to your repository interface still correct (from /presentation/screens)
import '../../domain/repositories/auth_repository.dart';

// ✅ robust OTP import (replace 'majurun' with the actual pubspec name)
import 'otp_screen.dart'; 


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  // UI state
  bool _loading = false;
  bool _obscure = true;
  String _countryCode = '+65';
  DateTime? _dob;
  String? _gender; // 'male' | 'female' | 'other'
  bool _agree = true;

  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 100, now.month, now.day);
    final last = DateTime(now.year - 13, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: first,
      lastDate: last,
      helpText: 'Select Date of Birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: const DatePickerThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _e164() {
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '$_countryCode$digits';
  }

  double _passwordScore(String v) {
    double s = 0;
    if (v.length >= 8) s += .25;
    if (RegExp(r'[A-Z]').hasMatch(v)) s += .2;
    if (RegExp(r'[a-z]').hasMatch(v)) s += .2;
    if (RegExp(r'[0-9]').hasMatch(v)) s += .2;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s += .15;
    return s.clamp(0, 1);
  }

  Color _scoreColor(double s, ColorScheme cs) {
    if (s < .35) return Colors.red.shade400;
    if (s < .7) return Colors.orange.shade600;
    return cs.primary;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _dob == null || _gender == null || !_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    setState(() => _loading = true);

    final e164 = _e164();
    final authRepo = context.read<AuthRepository>();

    try {
      await authRepo.verifyPhoneNumber(
        phoneNumber: e164,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() => _loading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phoneNumber: e164,
                onVerify: (code) async {
                  await authRepo.signInWithOtp(
                    verificationId: verificationId,
                    smsCode: code,
                  );
                  // AuthWrapper will pick up the signed-in state.
                },
              ),
            ),
          );
        },
        onError: (message) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Card(
              elevation: 0,
              color: cs.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run_rounded, size: 40, color: cs.primary),
                          const SizedBox(height: 8),
                          Text('Create your account', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            'Join MajuRun and start your journey',
                            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _fullName,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                hintText: 'e.g. Alex Tan',
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'name@domain.com',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Email is required';
                                final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
                                return ok ? null : 'Enter a valid email';
                              },
                            ),
                            const SizedBox(height: 12),

                            // Phone row
                            Row(
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: DropdownButtonFormField<String>(
                                    // 🔧 Flutter 3.33+ prefers `initialValue` over `value`
                                    initialValue: _countryCode,
                                    decoration: const InputDecoration(labelText: 'Code'),
                                    items: const [
                                      DropdownMenuItem(value: '+65', child: Text('+65 SG')),
                                      DropdownMenuItem(value: '+60', child: Text('+60 MY')),
                                      DropdownMenuItem(value: '+91', child: Text('+91 IN')),
                                      DropdownMenuItem(value: '+1', child: Text('+1 US')),
                                    ],
                                    onChanged: (v) => setState(() => _countryCode = v ?? '+65'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phone,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Mobile number',
                                      hintText: '9689 2876',
                                    ),
                                    validator: (v) {
                                      final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                                      if (digits.length < 7) return 'Enter a valid phone number';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // DOB & Gender
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickDob,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(labelText: 'Date of birth'),
                                      child: Text(_dob == null ? 'Tap to select' : _dateFmt.format(_dob!)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(value: 'male', label: Text('Male')),
                                      ButtonSegment(value: 'female', label: Text('Female')),
                                      ButtonSegment(value: 'other', label: Text('Other')),
                                    ],
                                    selected: {_gender ?? ''}..remove(''),
                                    onSelectionChanged: (s) => setState(() => _gender = s.first),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Password + strength
                            StatefulBuilder(
                              builder: (ctx, setPassState) {
                                final s = _passwordScore(_password.text);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _password,
                                      obscureText: _obscure,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'At least 8 characters',
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(() => _obscure = !_obscure),
                                          icon: Icon(
                                            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          ),
                                        ),
                                      ),
                                      onChanged: (_) => setPassState(() {}),
                                      validator: (v) => (v == null || v.length < 8)
                                          ? 'Use at least 8 characters'
                                          : null,
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: s,
                                        minHeight: 6,
                                        // 🔧 use new Material color role (no deprecation)
                                        color: _scoreColor(s, cs),
                                        backgroundColor: cs.surfaceContainerHighest,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s < .35 ? 'Weak' : s < .7 ? 'Medium' : 'Strong',
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: _scoreColor(s, cs)),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _agree,
                              onChanged: (v) => setState(() => _agree = v ?? false),
                              title: const Text(
                                'I agree to the Terms of Service and Privacy Policy.',
                              ),
                            ),

                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text.rich(
                                TextSpan(
                                  text:
                                      'This site is protected by reCAPTCHA and the Google ',
                                  children: [
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                                    ),
                                    const TextSpan(text: ' apply.'),
                                  ],
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),

                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: _loading
                                  ? FilledButton(
                                      onPressed: () {},
                                      child: const SizedBox(
                                        height: 52,
                                        child: Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    )
                                  : FilledButton.icon(
                                      onPressed: _submit,
                                      icon: const Icon(Icons.sms_rounded),
                                      label: const Text('Send OTP'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}