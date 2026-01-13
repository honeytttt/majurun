import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/workout/domain/repositories/workout_repository.dart';
import 'package:majurun/core/services/cloudinary_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  Uint8List? _fileBytes;
  bool _isVideo = false;
  bool _isUploading = false;

  Future<void> _pickFile(bool video) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = video 
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);
    
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _fileBytes = bytes;
        _isVideo = video;
      });
    }
  }

  Future<void> _submitPost() async {
    if (_textController.text.trim().isEmpty && _fileBytes == null) return;
    setState(() => _isUploading = true);

    try {
      String? finalUrl;
      if (_fileBytes != null) {
        finalUrl = await CloudinaryService().uploadImageBytes(_fileBytes!);
      }

      await context.read<WorkoutRepository>().savePost(
        userId: FirebaseAuth.instance.currentUser!.uid,
        text: _textController.text.trim(),
        imageUrl: finalUrl,
      );

      _textController.clear();
      setState(() => _fileBytes = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post Shared!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              border: InputBorder.none,
            ),
          ),
          if (_fileBytes != null)
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isVideo 
                ? const Icon(Icons.video_file, size: 50, color: Colors.green)
                : Image.memory(_fileBytes!, fit: BoxFit.cover),
            ),
          const Divider(),
          Row(
            children: [
              IconButton(onPressed: () => _pickFile(false), icon: const Icon(Icons.image_outlined, color: Colors.green)),
              IconButton(onPressed: () => _pickFile(true), icon: const Icon(Icons.videocam_outlined, color: Colors.green)),
              const Spacer(),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitPost,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: _isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Post", style: TextStyle(color: Colors.white)),
              )
            ],
          )
        ],
      ),
    );
  }
}