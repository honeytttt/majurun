import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'otp_screen.dart';

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

  String? _verificationId;

  void _onRegisterPressed() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }
    
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your birthday")),
      );
      return;
    }
    
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your gender")),
      );
      return;
    }

    setState(() => _loading = true);
    final authRepo = context.read<AuthRepository>();

    try {
      await authRepo.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _verificationId = verificationId;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phoneNumber: _phone.text.trim(),
                initialVerificationId: verificationId,
                onVerificationIdChanged: (newId) => _verificationId = newId,
                onVerify: (otpCode) => _finalize(_verificationId, otpCode),
              ),
            ),
          );
        },
        onError: (err) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _finalize(String? verId, String otp) async {
    if (verId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification expired. Please resend code.")),
      );
      return;
    }

    setState(() => _loading = true);
    
    try {
      final authRepo = context.read<AuthRepository>();
      
      // STEP 1: Create email/password account
      final user = await authRepo.signUpWithEmail(
        email: _email.text.trim(),
        password: _pass.text.trim(),
        firstName: _fName.text.trim(),
        lastName: _lName.text.trim(),
        dob: _dob!,
        gender: _gender!,
        phoneNumber: _phone.text.trim(),
      );
      
      if (user == null) throw 'Failed to create account';
      
      // STEP 2: Link phone number
      await authRepo.linkPhoneNumber(
        verificationId: verId,
        smsCode: otp,
      );
      
      if (!mounted) return;
      
      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Majurun"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _fName,
              decoration: const InputDecoration(
                labelText: "First Name",
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lName,
              decoration: const InputDecoration(
                labelText: "Last Name",
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (!v!.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: "Phone (e.g. +60...)",
                border: OutlineInputBorder(),
                hintText: "+60 12 345 6789",
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (!v!.startsWith('+')) return 'Must include country code (e.g. +60)';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (v!.length < 6) return 'Min 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
  decoration: const InputDecoration(
    labelText: "Gender",
    border: OutlineInputBorder(),
  ),
  value: _gender,
  items: const [
    DropdownMenuItem(value: "Male", child: Text("Male")),
    DropdownMenuItem(value: "Female", child: Text("Female")),
  ],
  onChanged: (v) => setState(() => _gender = v),
  validator: (v) => v == null ? 'Required' : null,
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
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Birthday",
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dob == null 
                      ? "Select Date" 
                      : DateFormat('dd/MM/yyyy').format(_dob!),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loading ? null : _onRegisterPressed,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "CONTINUE",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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