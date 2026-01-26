import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentImageUrl;
  final String currentEmail;
  final Function(String, String, dynamic, String) onSave;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.currentImageUrl,
    required this.currentEmail,
    required this.onSave,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;
  File? _imageFile;
  Uint8List? _webImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _bioController = TextEditingController(text: widget.currentBio);
    _emailController = TextEditingController(text: widget.currentEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => _webImage = bytes);
      } else {
        setState(() => _imageFile = File(picked.path));
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    
    dynamic imageData;
    if (kIsWeb) {
      imageData = _webImage;
    } else {
      imageData = _imageFile;
    }

    // Call the onSave function provided by HomeScreen
    await widget.onSave(
      _nameController.text.trim(),
      _bioController.text.trim(),
      imageData,
      _emailController.text.trim(),
    );

    // FIX: "use_build_context_synchronously" 
    // Check if the widget is still in the tree before popping
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF00E676);

    final ImageProvider avatarImage = kIsWeb
        ? (_webImage != null ? MemoryImage(_webImage!) : _networkProvider())
        : (_imageFile != null ? FileImage(_imageFile!) : _networkProvider());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("EDIT PROFILE", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text("Save", style: TextStyle(color: brandGreen, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(radius: 55, backgroundColor: Colors.grey[200], backgroundImage: avatarImage),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: brandGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildInputField("FULL NAME", _nameController),
            const SizedBox(height: 25),
            _buildInputField("BIO", _bioController, maxLines: 4),
            const SizedBox(height: 25),
            _buildInputField("EMAIL", _emailController),
          ],
        ),
      ),
    );
  }

  ImageProvider _networkProvider() {
    return widget.currentImageUrl.isNotEmpty
        ? NetworkImage(widget.currentImageUrl)
        : const NetworkImage('https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400');
  }

  Widget _buildInputField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.black)),
          ),
        ),
      ],
    );
  }
}