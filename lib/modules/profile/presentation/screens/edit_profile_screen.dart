import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentImageUrl;
  final String currentEmail;
  final String currentNickname;
  final Function(String, String, dynamic, String, String) onSave;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.currentImageUrl,
    required this.currentEmail,
    this.currentNickname = '',
    required this.onSave,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;
  late final TextEditingController _nicknameController;
  File? _imageFile;
  Uint8List? _webImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _bioController = TextEditingController(text: widget.currentBio);
    _emailController = TextEditingController(text: widget.currentEmail);
    _nicknameController = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Prevent picking if already saving
    if (_isSaving) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 70, // Added slight compression at picker level
    );
    
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
    // 1. Start Loading State
    setState(() => _isSaving = true);
    
    dynamic imageData;
    if (kIsWeb) {
      imageData = _webImage;
    } else {
      imageData = _imageFile;
    }

    try {
      // 2. Execute onSave (S3 Upload + Firestore Update)
      await widget.onSave(
        _nameController.text.trim(),
        _bioController.text.trim(),
        imageData,
        _emailController.text.trim(),
        _nicknameController.text.trim(),
      );

      // 3. Success: Return to profile
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      // 4. Handle Errors
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    }
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
          onPressed: () => _isSaving ? null : Navigator.pop(context),
        ),
        title: const Text(
          'EDIT PROFILE', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
        ),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save', 
                style: TextStyle(color: brandGreen, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
        ],
      ),
      // Use Stack to show the Loading Overlay
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 55, 
                        backgroundColor: Colors.grey[200], 
                        backgroundImage: avatarImage,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: brandGreen, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _buildInputField('FULL NAME', _nameController, enabled: !_isSaving),
                const SizedBox(height: 25),
                _buildInputField('NICKNAME (optional)', _nicknameController, enabled: !_isSaving, hint: 'e.g. Flash, Iron Mike...'),
                const SizedBox(height: 25),
                _buildInputField('BIO', _bioController, maxLines: 4, enabled: !_isSaving),
                const SizedBox(height: 25),
                _buildInputField('EMAIL', _emailController, enabled: !_isSaving),
              ],
            ),
          ),
          
          // The Loading Overlay
          if (_isSaving)
            Container(
              color: Colors.white.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: brandGreen),
                    const SizedBox(height: 20),
                    Text(
                      'Uploading to S3...',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  ImageProvider _networkProvider() {
    return widget.currentImageUrl.isNotEmpty
        ? NetworkImage(widget.currentImageUrl)
        : const NetworkImage('https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400');
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    {int maxLines = 1, bool enabled = true, String? hint}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: const TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.w800, 
            color: Colors.grey, 
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[100]!),
            ),
          ),
        ),
      ],
    );
  }
}