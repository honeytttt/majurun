import 'package:flutter/material.dart';
import '../utils/input_validators.dart';

/// A widget that displays password strength with visual feedback
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showRequirements;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showRequirements = true,
  });

  @override
  Widget build(BuildContext context) {
    final result = InputValidators.validatePassword(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength bar
        _buildStrengthBar(result.strength),
        const SizedBox(height: 8),
        // Strength label
        Row(
          children: [
            Text(
              'Strength: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
            Text(
              result.strength.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(result.strength.colorValue),
              ),
            ),
          ],
        ),
        if (showRequirements) ...[
          const SizedBox(height: 12),
          _buildRequirementsList(result.checks),
        ],
      ],
    );
  }

  Widget _buildStrengthBar(PasswordStrength strength) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.grey[800],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: constraints.maxWidth * strength.progressValue,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: _getGradientColors(strength),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Color> _getGradientColors(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.none:
        return [Colors.grey, Colors.grey];
      case PasswordStrength.weak:
        return [Colors.red, Colors.redAccent];
      case PasswordStrength.fair:
        return [Colors.orange, Colors.orangeAccent];
      case PasswordStrength.good:
        return [Colors.blue, Colors.lightBlue];
      case PasswordStrength.strong:
        return [Colors.green, Colors.lightGreen];
    }
  }

  Widget _buildRequirementsList(PasswordChecks checks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirement('At least 8 characters', checks.hasMinLength),
        _buildRequirement('One uppercase letter (A-Z)', checks.hasUppercase),
        _buildRequirement('One lowercase letter (a-z)', checks.hasLowercase),
        _buildRequirement('One number (0-9)', checks.hasNumber),
        _buildRequirement('One special character (!@#\$%)', checks.hasSpecialChar),
      ],
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? Colors.green : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met ? Colors.green : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact password strength indicator (just the bar)
class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    final result = InputValidators.validatePassword(password);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.grey[800],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: constraints.maxWidth * result.strength.progressValue,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Color(result.strength.colorValue),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          result.strength.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(result.strength.colorValue),
          ),
        ),
      ],
    );
  }
}

/// A text field with integrated password strength indicator
class PasswordFieldWithStrength extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final bool showRequirements;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  const PasswordFieldWithStrength({
    super.key,
    required this.controller,
    this.labelText = 'Password',
    this.hintText,
    this.showRequirements = true,
    this.onChanged,
    this.validator,
  });

  @override
  State<PasswordFieldWithStrength> createState() =>
      _PasswordFieldWithStrengthState();
}

class _PasswordFieldWithStrengthState extends State<PasswordFieldWithStrength> {
  bool _obscureText = true;
  String _password = '';

  @override
  void initState() {
    super.initState();
    _password = widget.controller.text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[500],
              ),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
          ),
          onChanged: (value) {
            setState(() {
              _password = value;
            });
            widget.onChanged?.call(value);
          },
          validator: widget.validator ??
              (value) {
                final result = InputValidators.validatePassword(value);
                return result.isValid ? null : result.errorMessage;
              },
        ),
        if (_password.isNotEmpty) ...[
          const SizedBox(height: 12),
          PasswordStrengthIndicator(
            password: _password,
            showRequirements: widget.showRequirements,
          ),
        ],
      ],
    );
  }
}
