import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestSyncScreen extends StatelessWidget {
  const TestSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Stats')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _syncUserStatsFromPosts(context),
          child: const Text('Sync Stats from Posts'),
        ),
      ),
    );
  }

  Future<void> _syncUserStatsFromPosts(BuildContext context) async {
    // ... (paste the entire sync function here)
  }
}