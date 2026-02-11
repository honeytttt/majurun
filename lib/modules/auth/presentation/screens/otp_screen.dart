import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final Function(String) onVerify;
  final String? initialVerificationId;
  final void Function(String newVerificationId)? onVerificationIdChanged;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.onVerify,
    this.initialVerificationId,
    this.onVerificationIdChanged,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _secondsRemaining = 30;
  Timer? _timer;

  String? _currentVerificationId;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.initialVerificationId;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        if (mounted) setState(() => timer.cancel());
      } else {
        if (mounted) setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _resendCode() async {
    if (_isLoading || _secondsRemaining > 0) return;
    final authRepo = context.read<AuthRepository>();
    setState(() => _isLoading = true);

    await authRepo.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber.trim(),
      onCodeSent: (newVerificationId) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _currentVerificationId = newVerificationId;
        });
        widget.onVerificationIdChanged?.call(newVerificationId);
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code has been sent.')),
        );
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      },
    );
  }

  void _submitCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    if (_currentVerificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please resend the code.')),
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    await widget.onVerify(code);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Verification Code", style: TextStyle(color: Colors.white)),
        backgroundColor: brandGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              "Enter the 6-digit code sent to\n${widget.phoneNumber}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => SizedBox(
                width: 45,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: Colors.green.withAlpha((0.05 * 255).round()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: brandGreen.withAlpha((0.3 * 255).round()),
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    }
                    if (value.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                    if (index == 5 && value.isNotEmpty) {
                      _submitCode();
                    }
                  },
                ),
              )),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)
                  ),
                ),
                onPressed: _isLoading ? null : _submitCode,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "VERIFY OTP",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            if (_secondsRemaining > 0)
              Text(
                "Resend in ${_secondsRemaining}s",
                style: const TextStyle(color: Colors.grey),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _resendCode,
                child: const Text(
                  "Didn't receive code? RESEND",
                  style: TextStyle(color: Color(0xFF2E7D32)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}