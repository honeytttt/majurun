import 'package:flutter/material.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final Function(String) onVerify;

  const OtpScreen({super.key, required this.phoneNumber, required this.onVerify});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  void _submitCode() async {
    String code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() => _isLoading = true);
    await widget.onVerify(code);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verification Code")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text("Enter the 6-digit code sent to\n${widget.phoneNumber}", 
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
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
                  decoration: const InputDecoration(counterText: "", border: OutlineInputBorder()),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
                    if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
                    if (index == 5 && value.isNotEmpty) _submitCode();
                  },
                ),
              )),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCode,
                child: _isLoading ? const CircularProgressIndicator() : const Text("VERIFY OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}