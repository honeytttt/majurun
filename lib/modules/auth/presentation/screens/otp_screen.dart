import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/auth_repository.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final Function(String) onVerify;
  final Function(String verificationId)? onNewVerificationId;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.onVerify,
    this.onNewVerificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    // Rebuild when any box gains/loses focus so the highlighted border updates
    for (final f in _focusNodes) {
      f.addListener(() { if (mounted) setState(() {}); });
    }
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId) {
          if (mounted) {
            setState(() => _isResending = false);
            _startResendCountdown();
            // Clear OTP fields
            for (final c in _controllers) {
              c.clear();
            }
            _focusNodes[0].requestFocus();

            // Notify parent of new verification ID if callback provided
            widget.onNewVerificationId?.call(verificationId);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP sent successfully!'),
                backgroundColor: Color(0xFF00E676),
              ),
            );
          }
        },
        onError: (message) {
          if (mounted) {
            setState(() => _isResending = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $message'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitCode() async {
    if (_isLoading) return;
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() => _isLoading = true);
    try {
      await widget.onVerify(code);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final isEmailExists = msg.contains('email-already-in-use') ||
          msg.contains('already registered') ||
          msg.contains('already in use');
      if (isEmailExists) {
        _showEmailExistsDialog(e.toString());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmailExistsDialog(String rawError) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_pin_rounded, color: Colors.orange.shade700, size: 32),
        ),
        title: const Text(
          'Account Already Exists',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This email is already registered with MajuRun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in with your existing account, or reset your password if you\'ve forgotten it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  // Pop OTP screen and signup screen back to login
                  int count = 0;
                  Navigator.of(context).popUntil((_) => count++ >= 2);
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Go to Sign In'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Try Different Email'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int index) {
    final cs = Theme.of(context).colorScheme;
    final isFocused = _focusNodes[index].hasFocus;

    // Container provides the visible box — TextField inside has NO internal
    // decoration. This bypasses Samsung/MIUI autofill masking that turns digits
    // into "•" or makes them invisible when using filled InputDecoration.
    return Container(
      width: 52,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? cs.primary : cs.outlineVariant,
          width: isFocused ? 2.5 : 1.5,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: .18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: index < 5 ? TextInputAction.next : TextInputAction.done,
        maxLength: 1,
        obscureText: false,       // explicit — prevents autofill from hiding digits
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [], // disables Samsung / MIUI autofill masking
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF111111), // hardcoded near-black
          height: 1.0,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onTap: () {
          _controllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[index].text.length,
          );
        },
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
          if (index == 5 && v.isNotEmpty) _submitCode();
        },
        onSubmitted: (_) {
          if (index == 5) _submitCode();
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
                _isResending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: _resendCountdown > 0 || _isLoading ? null : _resendOtp,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          _resendCountdown > 0
                              ? 'Resend in ${_resendCountdown}s'
                              : 'Resend OTP',
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