import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:majurun/core/services/cloudinary_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentImageUrl;
  final String currentEmail;
  final Function(String, String, String?) onSave; // name, bio, imageUrl

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
  final CloudinaryService _cloudinary = CloudinaryService();

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

  /// Pick image (Mobile + Web)
  Future<void> _pickImage() async {
    final picker = ImagePicker();

    if (kIsWeb) {
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        _webImage = await picked.readAsBytes();
        setState(() {});
      }
    } else {
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        _imageFile = File(picked.path);
        setState(() {});
      }
    }
  }

  /// Save profile
  Future<void> _saveProfile() async {
    String? imageUrl = widget.currentImageUrl;

    if (_imageFile != null) {
      final bytes = await _imageFile!.readAsBytes();
      imageUrl = await _cloudinary.uploadMedia(
        bytes,
        _imageFile!.path.split('/').last,
        false,
      );
    } else if (_webImage != null) {
      imageUrl = await _cloudinary.uploadMedia(
        _webImage!,
        "web_upload.png",
        false,
      );
    }

    widget.onSave(
      _nameController.text.trim(),
      _bioController.text.trim(),
      imageUrl,
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final brandGreen = Theme.of(context).colorScheme.primary;

    final ImageProvider<Object> avatarImage = kIsWeb
        ? (_webImage != null
            ? MemoryImage(_webImage!) as ImageProvider<Object>
            : (widget.currentImageUrl.isNotEmpty
                ? NetworkImage(widget.currentImageUrl)
                : const NetworkImage(
                    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400')))
        : (_imageFile != null
            ? FileImage(_imageFile!) as ImageProvider<Object>
            : (widget.currentImageUrl.isNotEmpty
                ? NetworkImage(widget.currentImageUrl)
                : const NetworkImage(
                    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400')));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "EDIT PROFILE",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              "Save",
              style: TextStyle(
                color: brandGreen,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
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
                      child: const Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Colors.black,
                      ),
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

  Widget _buildInputField(String label, TextEditingController controller,
      {int maxLines = 1}) {
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
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }
}
