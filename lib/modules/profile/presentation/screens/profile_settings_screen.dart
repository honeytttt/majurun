import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentImageUrl;
  final String currentEmail;
  final String currentLocation;
  final Function(String, String, dynamic, String, String) onSave; // name, bio, image(File/Uint8List), email, location

  const ProfileSettingsScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.currentImageUrl,
    required this.currentEmail,
    this.currentLocation = '',
    required this.onSave,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;
  late final TextEditingController _locationController;
  File? _imageFile;
  Uint8List? _webImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _bioController = TextEditingController(text: widget.currentBio);
    _emailController = TextEditingController(text: widget.currentEmail);
    _locationController = TextEditingController(text: widget.currentLocation);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Pick image (Mobile + Web)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    if (kIsWeb) {
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null && mounted) {
        _webImage = await picked.readAsBytes();
        setState(() {});
      }
    } else {
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null && mounted) {
        _imageFile = File(picked.path);
        setState(() {});
      }
    }
  }

  /// Save profile
  Future<void> _saveProfile() async {
    dynamic imageData;
    if (_imageFile != null) {
      imageData = _imageFile!;
    } else if (_webImage != null) {
      imageData = _webImage!;
    }

    widget.onSave(
      _nameController.text.trim(),
      _bioController.text.trim(),
      imageData,
      _emailController.text.trim(),
      _locationController.text.trim(),
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final brandGreen = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
        title: const Text("PROFILE SETTINGS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text("Save", style: TextStyle(color: brandGreen, fontWeight: FontWeight.bold, fontSize: 16)),
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
                    child: _buildAvatarImage(),
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
            _buildInputField("FULL NAME", _nameController),
            const SizedBox(height: 25),
            _buildInputField("BIO", _bioController, maxLines: 4),
            const SizedBox(height: 25),
            _buildInputField("LOCATION", _locationController, icon: Icons.location_on_outlined),
            const SizedBox(height: 25),
            _buildInputField("EMAIL", _emailController, enabled: false),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage() {
    // Priority: picked image > current URL > default icon
    if (_webImage != null) {
      return ClipOval(
        child: Image.memory(
          _webImage!,
          fit: BoxFit.cover,
          width: 110,
          height: 110,
        ),
      );
    }
    
    if (_imageFile != null) {
      return ClipOval(
        child: Image.file(
          _imageFile!,
          fit: BoxFit.cover,
          width: 110,
          height: 110,
        ),
      );
    }
    
    if (widget.currentImageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          widget.currentImageUrl,
          fit: BoxFit.cover,
          width: 110,
          height: 110,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00E676),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Settings avatar load error: $error');
            return const Icon(Icons.person, size: 55, color: Colors.grey);
          },
        ),
      );
    }
    
    // Default icon
    return const Icon(Icons.person, size: 55, color: Colors.grey);
  }

  Widget _buildInputField(String label, TextEditingController controller, {int maxLines = 1, bool enabled = true, IconData? icon}) {
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
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.black),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
      ],
    );
  }
}