import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../workout/domain/repositories/workout_repository.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isPosting = false;

  Future<void> _handleSave() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await context.read<WorkoutRepository>().savePost(
        userId: user?.uid ?? '',
        userName: user?.displayName ?? 'Runner',
        text: _textController.text.trim(),
        imageUrl: null, // You can add image picker logic here later
      );

      if (mounted) {
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post shared!")));
        // Optionally switch back to Feed index
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Post", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _handleSave,
            child: _isPosting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text("Post", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.image, color: Colors.green), onPressed: () {}),
                IconButton(icon: const Icon(Icons.location_on, color: Colors.red), onPressed: () {}),
              ],
            )
          ],
        ),
      ),
    );
  }
}