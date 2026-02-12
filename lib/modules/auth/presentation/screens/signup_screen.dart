import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'otp_screen.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';

// Conditional import for web-only helper
import 'package:majurun/web/recaptcha_helper.dart'
    if (dart.library.html) 'package:majurun/web/recaptcha_helper.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _fName = TextEditingController();
  final _lName = TextEditingController();
  final _phone = TextEditingController();

  DateTime? _dob;
  String? _gender;
  bool _loading = false;
  bool _obscurePassword = true;

  InputDecoration _buildInput(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 22, color: Colors.blueAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Future<void> _onRegisterPressed() async {
    if (!_formKey.currentState!.validate() || _dob == null || _gender == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    // Get reCAPTCHA token (web platform only)
    String? token;
    try {
      token = await getRecaptchaToken('signup_start');
    } catch (e) {
      debugPrint('reCAPTCHA token error: $e');
    }

    if (token == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Security check failed. Please disable ad blockers or try again."),
        ),
      );
      return;
    }

    // Verify token with Cloud Function
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final callable = functions.httpsCallable('verifyRecaptcha');

      final result = await callable.call({
        'token': token,
        'action': 'signup_start',
      });

      final data = result.data as Map<String, dynamic>;
      final score = (data['score'] as num?)?.toDouble() ?? 0.0;
      final valid = data['valid'] as bool? ?? false;

      if (!valid) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Security check failed (score: ${score.toStringAsFixed(2)}). Please try again.",
            ),
          ),
        );
        return;
      }

      debugPrint("reCAPTCHA passed with score: $score");
    } catch (e) {
      debugPrint('Cloud Function call failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Security verification failed: $e")),
      );
      return;
    }

    // Proceed with phone verification
    final authRepo = context.read<AuthRepository>();

    try {
      await authRepo.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() => _loading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phoneNumber: _phone.text.trim(),
                onVerify: (otpCode) => _handleFinalVerification(verificationId, otpCode),
              ),
            ),
          );
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleFinalVerification(String verId, String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.signInWithOtp(verificationId: verId, smsCode: code);
      await authRepo.signUpWithEmail(
        email: _email.text.trim(),
        password: _pass.text.trim(),
        firstName: _fName.text.trim(),
        lastName: _lName.text.trim(),
        dob: _dob!,
        gender: _gender!,
        phoneNumber: _phone.text.trim(),
      );

      if (!mounted) return;
      _showSuccessDialog(messenger, navigator, _email.text.trim());
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showSuccessDialog(ScaffoldMessengerState messenger, NavigatorState navigator, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.mark_email_unread, size: 60, color: Colors.blueAccent),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Phone Verified!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text(
              "We've sent a final activation link to $email. Please verify your email to log in.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => navigator.popUntil((route) => route.isFirst),
            child: const Text("I UNDERSTAND"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Join Majurun", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text("Step 1: Profile Info",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _fName, decoration: _buildInput("First Name", Icons.person_outline))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _lName, decoration: _buildInput("Last Name", Icons.person_outline))),
              ],
            ),
            const SizedBox(height: 16),
            // ignore: deprecated_member_use
            DropdownButtonFormField<String>(
              decoration: _buildInput("Gender", Icons.wc),
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
              items: ["Male", "Female", "Other"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _dob = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                child: Text(_dob == null ? "Select Date of Birth" : DateFormat('dd MMMM yyyy').format(_dob!)),
              ),
            ),
            const SizedBox(height: 32),
            const Text("Step 2: Security",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            TextFormField(controller: _email, decoration: _buildInput("Email Address", Icons.email_outlined)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _buildInput("Mobile (+CountryCode)", Icons.phone_android),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pass,
              obscureText: _obscurePassword,
              decoration: _buildInput("Password", Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "This site is protected by reCAPTCHA and the Google Privacy Policy and Terms of Service apply.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _onRegisterPressed,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("VERIFY & CREATE PROFILE"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _fName.dispose();
    _lName.dispose();
    _phone.dispose();
    super.dispose();
  }
}