// lib/modules/auth/presentation/screens/signup_screen.dart
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/repositories/auth_repository.dart';
import 'otp_screen.dart';
import 'country_phone_data.dart';

const String kTermsAndConditionsUrl = 'https://www.majurun.com/terms-and-conditions.html';

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

  // UI State
  bool _loading = false;
  bool _obscure = true;
  Country _selectedCountry =
      kCountries.firstWhere((c) => c.iso2 == 'SG', orElse: () => kCountries.first);
  DateTime? _dob;
  String? _gender; // 'male'|'female'|'other'
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

  String _e164() {
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '${_selectedCountry.dialCode}$digits';
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

  Future<void> _openCountryPicker() async {
    final chosen = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryPickerSheet(selected: _selectedCountry),
    );
    if (chosen != null) setState(() => _selectedCountry = chosen);
  }

  Future<void> _openDobPicker() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 100, now.month, now.day);
    final last = DateTime(now.year - 13, now.month, now.day); // 13+ years

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DobPickerSheet(
        firstDate: first,
        lastDate: last,
        initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

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

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _dob == null || _gender == null || !_agree) {
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
                  // AuthWrapper should react to sign-in success.
                },
              ),
            ),
          );
        },
        onError: (message) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      body: Stack(
        children: [
          // Gradient background (Material 3 friendly)
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
          // Decorative blurred blobs
          Positioned(
            top: -60,
            right: -60,
            child: _Blob(color: cs.primary.withValues(alpha: .20), size: 200),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: _Blob(color: cs.secondary.withValues(alpha: .16), size: 160),
          ),

          // Center frosted card
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outline.withValues(alpha: .12)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_run_rounded, size: 36, color: cs.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Create your account',
                                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Join MajuRun and start your journey',
                            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
                                    labelText: 'Full name *',
                                    hintText: 'e.g. Alex Tan',
                                  ),
                                  validator: (v) => (v == null || v.trim().length < 2)
                                      ? 'Enter your full name'
                                      : null,
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email *',
                                    hintText: 'name@domain.com',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Email is required';
                                    }
                                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                        .hasMatch(v.trim());
                                    return ok ? null : 'Enter a valid email';
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Country + phone row
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: _openCountryPicker,
                                        child: InputDecorator(
                                          decoration: const InputDecoration(labelText: 'Country'),
                                          child: Row(
                                            children: [
                                              Text(_selectedCountry.flag,
                                                  style: const TextStyle(fontSize: 18)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${_selectedCountry.name} (${_selectedCountry.dialCode})',
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Icon(Icons.expand_more_rounded, size: 18),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 5,
                                      child: TextFormField(
                                        controller: _phone,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Mobile number *',
                                          hintText: '9689 2876',
                                        ),
                                        validator: (v) {
                                          final digits = (v ?? '')
                                              .replaceAll(RegExp(r'[^0-9]'), '');
                                          if (digits.length < 6) {
                                            return 'Enter a valid phone number';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // DOB + Gender row
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: _openDobPicker,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InputDecorator(
                                          decoration:
                                              const InputDecoration(labelText: 'Date of birth *'),
                                          child: Text(_dob == null
                                              ? 'Tap to select'
                                              : _dateFmt.format(_dob!)),
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
                                        // IMPORTANT: allow empty selection until the user chooses
                                        emptySelectionAllowed: true,
                                        selected: _gender == null ? <String>{} : <String>{_gender!},
                                        onSelectionChanged: (s) => setState(() => _gender = s.firstOrNull),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Password + strength
                                StatefulBuilder(
                                  builder: (ctx, setPassState) {
                                    final s = _passwordScore(_password.text);
                                    final color = s < .35
                                        ? Colors.red.shade400
                                        : s < .7
                                            ? Colors.orange.shade600
                                            : cs.primary;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: _password,
                                          obscureText: _obscure,
                                          textInputAction: TextInputAction.done,
                                          decoration: InputDecoration(
                                            labelText: 'Password *',
                                            hintText: 'At least 8 characters',
                                            suffixIcon: IconButton(
                                              onPressed: () =>
                                                  setState(() => _obscure = !_obscure),
                                              icon: Icon(_obscure
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded),
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
                                            color: color,
                                            backgroundColor:
                                                cs.surfaceContainerHighest,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          s < .35 ? 'Weak' : s < .7 ? 'Medium' : 'Strong',
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: color),
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
                                  title: Text.rich(
                                    TextSpan(
                                      text: 'I agree to the ',
                                      children: [
                                        TextSpan(
                                          text: 'Terms and Conditions',
                                          style: TextStyle(
                                            color: cs.primary,
                                            decoration: TextDecoration.underline,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _openTermsAndConditions(),
                                        ),
                                        const TextSpan(text: ' and Privacy Policy.'),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // reCAPTCHA disclosure (required on web)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text.rich(
                                    TextSpan(
                                      text:
                                          'This site is protected by reCAPTCHA and the Google ',
                                      children: [
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(color: cs.primary),
                                        ),
                                        const TextSpan(text: ' and '),
                                        TextSpan(
                                          text: 'Terms of Service',
                                          style: TextStyle(color: cs.primary),
                                        ),
                                        const TextSpan(text: ' apply.'),
                                      ],
                                    ),
                                    style: text.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
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
                        ],
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

// ---------- Private UI bits ----------

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
          BoxShadow(
            color: color.withValues(alpha: .6),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

// Country picker bottom sheet with search
class _CountryPickerSheet extends StatefulWidget {
  final Country selected;
  const _CountryPickerSheet({required this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    final filtered = kCountries
        .where((c) =>
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            c.dialCode.contains(_query) ||
            c.iso2.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.only(
            top: 12,
            left: 16,
            right: 16,
            bottom: media.viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: .95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: .12)),
            ),
          ),
          child: SafeArea(
            top: false,
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
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search country or dial code',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final selected = c.iso2 == widget.selected.iso2;
                      return ListTile(
                        leading: Text(c.flag, style: const TextStyle(fontSize: 20)),
                        title: Text(c.name),
                        subtitle: Text(c.dialCode),
                        trailing: selected ? Icon(Icons.check_rounded, color: cs.primary) : null,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// DOB picker bottom sheet with CalendarDatePicker
class _DobPickerSheet extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime initialDate;

  const _DobPickerSheet({
    required this.firstDate,
    required this.lastDate,
    required this.initialDate,
  });

  @override
  State<_DobPickerSheet> createState() => _DobPickerSheetState();
}

class _DobPickerSheetState extends State<_DobPickerSheet> {
  late DateTime _temp = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: media.viewInsets.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: .96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: .12)),
            ),
          ),
          child: SafeArea(
            top: false,
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
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(Icons.cake_rounded, color: cs.primary),
                  title: const Text('Select your date of birth'),
                  subtitle: const Text('You must be at least 13 years old'),
                ),
                CalendarDatePicker(
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  initialDate: _temp,
                  onDateChanged: (d) => _temp = d,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, _temp),
                        child: const Text('Use this date'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}