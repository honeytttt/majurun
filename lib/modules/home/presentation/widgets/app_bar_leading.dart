// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

class AppBarLeading extends StatelessWidget {
  final VoidCallback onProfilePressed;

  const AppBarLeading({
    super.key,
    required this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.account_circle_outlined,
            color: Colors.black,
            size: 28,
          ),
          onPressed: onProfilePressed,
        ),
        const SizedBox(width: 12),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.question_answer_outlined,
            color: Colors.black,
            size: 24,
          ),
          onPressed: () => debugPrint("Forum clicked"),
        ),
      ],
    );
  }
}