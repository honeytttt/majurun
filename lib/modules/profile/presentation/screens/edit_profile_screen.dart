// lib/modules/profile/presentation/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Warning resolved: Now in use

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final Function(String name, String bio, File? imageFile) onSave;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.onSave,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _bioController = TextEditingController(text: widget.currentBio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Logic to resolve the unused import and enable photo selection
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("EDIT PROFILE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSave(_nameController.text.trim(), _bioController.text.trim(), _imageFile);
              Navigator.pop(context); // Back to Settings
              Navigator.pop(context); // Back to Profile
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null ? const Icon(Icons.camera_alt, size: 30) : null,
              ),
            ),
            const SizedBox(height: 10),
            const Text("Tap to change photo", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 30),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "FULL NAME")),
            const SizedBox(height: 20),
            TextField(controller: _bioController, decoration: const InputDecoration(labelText: "BIO"), maxLines: 3),
          ],
        ),
      ),
    );
  }
}