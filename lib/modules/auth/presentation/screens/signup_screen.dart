import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    try {
      await authRepo.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text("Join the MajuRun Community", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              CustomTextField(
                controller: _nameController,
                hintText: "Full Name",
                icon: Icons.person_outline,
                validator: (val) => val!.isEmpty ? "Enter your name" : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                hintText: "Email Address",
                icon: Icons.email_outlined,
                validator: (val) => !val!.contains("@") ? "Invalid email" : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                hintText: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
                validator: (val) => val!.length < 6 ? "Min 6 characters" : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Sign Up", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}