import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _nickname = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _loading = false;

  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Google/social login if available
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _fullName.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _openDobPicker() async {
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DobPickerSheet(
        firstDate: DateTime(now.year - 100, now.month, now.day),
        lastDate: DateTime(now.year - 13, now.month, now.day),
        initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final nameParts = _fullName.text.trim().split(RegExp(r'\s+'));
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final nicknameVal = _nickname.text.trim();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'displayName': _fullName.text.trim(),
        if (nicknameVal.isNotEmpty) 'nickname': nicknameVal,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'dob': _dob!.toIso8601String(),
        'gender': _gender,
        'phoneNumber': '',
        'createdAt': FieldValue.serverTimestamp(),
        'workoutsCount': 0,
        'totalKm': 0.0,
        'totalRunSeconds': 0,
        'totalCalories': 0,
        'postsCount': 0,
        'followersCount': 0,
        'followingCount': 0,
        'badge5k': 0,
        'badge10k': 0,
        'badgeHalf': 0,
        'badgeFull': 0,
      }, SetOptions(merge: true));

      await user.updateDisplayName(_fullName.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
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
                  cs.secondary.withValues(alpha: .08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -60, right: -60,
              child: _Blob(color: cs.primary.withValues(alpha: .18), size: 200)),
          Positioned(bottom: -40, left: -40,
              child: _Blob(color: cs.secondary.withValues(alpha: .14), size: 160)),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: .12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.directions_run_rounded,
                                    size: 48, color: cs.primary),
                              ),
                              const SizedBox(height: 16),
                              Text('Welcome to MajuRun!',
                                  style: text.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(
                                "Tell us a bit about yourself\nso we can personalise your experience.",
                                textAlign: TextAlign.center,
                                style: text.bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                              ),
                              const SizedBox(height: 32),

                              // Full Name
                              TextFormField(
                                controller: _fullName,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(Icons.person_outline, color: cs.primary),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) => (v == null || v.trim().length < 2)
                                    ? 'Enter your full name'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Nickname (optional)
                              TextFormField(
                                controller: _nickname,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Nickname (optional)',
                                  hintText: 'e.g. Flash, Iron Mike...',
                                  prefixIcon: Icon(Icons.tag, color: cs.primary),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Date of Birth
                              InkWell(
                                onTap: _openDobPicker,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Date of birth',
                                    prefixIcon: Icon(Icons.cake_outlined, color: cs.primary),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    _dob == null ? 'Tap to select' : _dateFmt.format(_dob!),
                                    style: TextStyle(
                                      color: _dob == null ? cs.onSurfaceVariant : cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Gender
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Gender',
                                    style: text.bodyMedium
                                        ?.copyWith(color: cs.onSurfaceVariant)),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: 'male',
                                      icon: Icon(Icons.male_rounded),
                                      label: Text('Male')),
                                  ButtonSegment(
                                      value: 'female',
                                      icon: Icon(Icons.female_rounded),
                                      label: Text('Female')),
                                ],
                                emptySelectionAllowed: true,
                                selected: _gender == null
                                    ? <String>{}
                                    : <String>{_gender!},
                                onSelectionChanged: (s) =>
                                    setState(() => _gender = s.firstOrNull),
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.comfortable,
                                ),
                              ),

                              const SizedBox(height: 32),

                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _submit,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.rocket_launch_rounded),
                                  label: const Text('Get Started',
                                      style: TextStyle(
                                          fontSize: 17, fontWeight: FontWeight.bold)),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Already have an account?',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () async {
                                            await context
                                                .read<AuthRepository>()
                                                .signOut();
                                            // AuthWrapper will now show LoginScreen
                                          },
                                    child: Text('Sign In',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold)),
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
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .6), blurRadius: 60, spreadRadius: 10)
          ],
        ),
      );
}

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
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.cake_rounded, color: cs.primary),
              title: const Text('Date of birth'),
              subtitle: const Text('You must be at least 13 years old'),
            ),
            CalendarDatePicker(
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              initialDate: _temp,
              onDateChanged: (d) => _temp = d,
            ),
            const SizedBox(height: 8),
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
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
