import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// IMPORT THE INTERFACE, NOT THE FIREBASE REPOSITORY
import '../../domain/repositories/auth_repository.dart';

class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context) {
    // This now correctly finds the AuthRepository type
    final authRepo = context.read<AuthRepository>();

    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("OR", style: TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        
        // Google Button
        _socialButton(
          label: "Continue with Google",
          iconPath: "assets/icons/google.png",
          color: Colors.white,
          textColor: Colors.black,
          onTap: () async {
            try {
              await authRepo.signInWithGoogle();
            } catch (e) {
              if (!context.mounted) return; // Fixes 'async gap' info
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Google Login Failed: $e")),
              );
            }
          },
        ),
        
        const SizedBox(height: 12),
        
        // Facebook Button
        _socialButton(
          label: "Continue with Facebook",
          iconPath: "assets/icons/facebook.png",
          color: const Color(0xFF1877F2),
          textColor: Colors.white,
          onTap: () async {
            try {
              await authRepo.signInWithFacebook();
            } catch (e) {
              if (!context.mounted) return; // Fixes 'async gap' info
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Facebook Login Failed: $e")),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _socialButton({
    required String label,
    required String iconPath,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: color == Colors.white ? Border.all(color: Colors.grey[300]!) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.login), 
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}