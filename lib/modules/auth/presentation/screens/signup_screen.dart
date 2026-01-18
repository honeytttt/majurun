import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Ensure intl is in pubspec.yaml
import '../../domain/repositories/auth_repository.dart';

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

  // Function to handle Date Selection
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dob) {
      setState(() {
        _dob = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(controller: _fName, decoration: const InputDecoration(labelText: "First Name")),
            TextFormField(controller: _lName, decoration: const InputDecoration(labelText: "Last Name")),
            TextFormField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
            TextFormField(controller: _pass, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            TextFormField(controller: _phone, decoration: const InputDecoration(labelText: "Phone Number")),
            
            const SizedBox(height: 10),
            // FIXED DOB DISPLAY
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListTile(
                title: const Text("Date of Birth"),
                subtitle: Text(
                  _dob == null 
                    ? "Not Selected" 
                    : DateFormat('dd MMMM yyyy').format(_dob!), // Reactive update
                  style: TextStyle(color: _dob == null ? Colors.red : Colors.blue),
                ),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _selectDate(context),
              ),
            ),

            DropdownButtonFormField<String>(
              value: _gender,
              items: ["Male", "Female", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _gender = v),
              decoration: const InputDecoration(labelText: "Gender"),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _loading ? null : () async {
                if (!_formKey.currentState!.validate() || _dob == null || _gender == null) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Missing fields!")));
                   return;
                }
                setState(() => _loading = true);
                try {
                  await context.read<AuthRepository>().signUpWithEmail(
                    email: _email.text, password: _pass.text, firstName: _fName.text,
                    lastName: _lName.text, dob: _dob!, gender: _gender!, phoneNumber: _phone.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Verification email sent! Check your inbox."))
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: _loading ? const CircularProgressIndicator() : const Text("CREATE ACCOUNT"),
            ),
          ],
        ),
      ),
    );
  }
}