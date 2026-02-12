// lib/otp_screen.dart
import 'package:flutter/material.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final Function(String) onVerify;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.onVerify,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() => _isLoading = true);
    await widget.onVerify(code);
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: const InputDecoration(
          counterText: "",
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
          if (index == 5 && v.isNotEmpty) _submitCode();
        },
      ),
    );
    }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Code')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sms_rounded, size: 36, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  'Enter the 6‑digit code sent to',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.phoneNumber,
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, _otpBox),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submitCode,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify OTP'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isLoading ? null : () {
                    // Keep minimal (resend handled by backing screen if needed)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please go back and send OTP again.')),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Resend'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}