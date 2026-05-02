import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/utils/majurun_debugger.dart';

/// TEMPORARY DEBUG SCREEN
/// Add this to your app navigation temporarily to fix issues
/// 
/// How to use:
/// 1. Add a button in your settings to open this screen
/// 2. Tap buttons to run diagnostics and fixes
/// 3. Remove this screen after everything works

class DebugFixScreen extends StatelessWidget {
  const DebugFixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Guard: never show debug tools in production builds
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Not available')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Debug & Fix'),
        backgroundColor: Colors.orange,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Diagnostic Tools',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Run these to identify and fix issues. Check the console for output.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          
          // Run Full Diagnostic
          _buildButton(
            context,
            icon: Icons.bug_report,
            title: 'Run Full Diagnostic',
            subtitle: 'Check everything (recommended first)',
            color: Colors.blue,
            onPressed: () async {
              if (!context.mounted) return;
              _showLoading(context);
              await MajurunDebugger.runFullDiagnostic();
              if (!context.mounted) return;
              Navigator.pop(context);
              _showSuccess(context, 'Check console for results');
            },
          ),
          
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          
          const Text(
            'Individual Checks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          
          // Check User Document
          _buildButton(
            context,
            icon: Icons.person_search,
            title: 'Check My User Document',
            subtitle: 'See what\'s in Firestore',
            color: Colors.purple,
            onPressed: () async {
              if (!context.mounted) return;
              _showLoading(context);
              await MajurunDebugger.checkMyUserDocument();
              if (!context.mounted) return;
              Navigator.pop(context);
              _showSuccess(context, 'Check console for details');
            },
          ),
          
          const SizedBox(height: 10),
          
          // Check Posts
          _buildButton(
            context,
            icon: Icons.post_add,
            title: 'Check My Posts',
            subtitle: 'Verify post ownership',
            color: Colors.green,
            onPressed: () async {
              if (!context.mounted) return;
              _showLoading(context);
              await MajurunDebugger.checkMyPosts();
              if (!context.mounted) return;
              Navigator.pop(context);
              _showSuccess(context, 'Check console for details');
            },
          ),
          
          const SizedBox(height: 10),
          
          // Test Permissions
          _buildButton(
            context,
            icon: Icons.security,
            title: 'Test Firestore Permissions',
            subtitle: 'Check what you can/can\'t do',
            color: Colors.amber,
            onPressed: () async {
              if (!context.mounted) return;
              _showLoading(context);
              await MajurunDebugger.testFirestorePermissions();
              if (!context.mounted) return;
              Navigator.pop(context);
              _showSuccess(context, 'Check console for results');
            },
          ),
          
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          
          const Text(
            'Fixes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          
          // Fix User Document
          _buildButton(
            context,
            icon: Icons.build,
            title: 'Fix My User Document',
            subtitle: 'Add missing counters & fields',
            color: Colors.orange,
            onPressed: () async {
              if (!context.mounted) return;
              final confirmed = await _showConfirmDialog(
                context,
                'Fix User Document?',
                'This will add/update followersCount and followingCount fields.',
              );
              
              if (confirmed ?? false) {
                if (!context.mounted) return;
                _showLoading(context);
                await MajurunDebugger.fixMyUserDocument();
                if (!context.mounted) return;
                Navigator.pop(context);
                _showSuccess(context, 'Fixed! Restart app to see changes.');
              }
            },
          ),
          
          const SizedBox(height: 30),
          
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      'Instructions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text('1. Run "Full Diagnostic" first'),
                Text('2. Check the console output'),
                Text('3. Run "Fix My User Document" if needed'),
                Text('4. Update Firestore rules (see guide)'),
                Text('5. Restart app'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fix It'),
          ),
        ],
      ),
    );
  }
}