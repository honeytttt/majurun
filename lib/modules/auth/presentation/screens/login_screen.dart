import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    try {
      await authRepo.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Failed: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_run, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text("MajuRun", 
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
              const Text("Keep Moving Forward", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              CustomTextField(
                controller: _emailController,
                hintText: "Email",
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                hintText: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Login", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: const Text("Don't have an account? Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}