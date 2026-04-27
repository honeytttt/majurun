import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:majurun/core/services/account_deletion_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentImageUrl;
  final String currentEmail;
  final String currentLocation;
  final String currentNickname;
  final String currentPhone;
  final Function(String, String, dynamic, String, String, String, String) onSave; // name, bio, image, email, location, nickname, phone

  const ProfileSettingsScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.currentImageUrl,
    required this.currentEmail,
    this.currentLocation = '',
    this.currentNickname = '',
    this.currentPhone = '',
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
  late final TextEditingController _nicknameController;
  late final TextEditingController _phoneController;
  File? _imageFile;
  Uint8List? _webImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _bioController = TextEditingController(text: widget.currentBio);
    _emailController = TextEditingController(text: widget.currentEmail);
    _locationController = TextEditingController(text: widget.currentLocation);
    _nicknameController = TextEditingController(text: widget.currentNickname);
    _phoneController = TextEditingController(text: widget.currentPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
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
      _nicknameController.text.trim(),
      _phoneController.text.trim(),
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
            _buildInputField("NICKNAME (optional)", _nicknameController, hint: "e.g. Flash, Iron Mike..."),
            const SizedBox(height: 25),
            _buildInputField("BIO", _bioController, maxLines: 4),
            const SizedBox(height: 25),
            _buildInputField("LOCATION", _locationController, icon: Icons.location_on_outlined),
            const SizedBox(height: 25),
            _buildInputField(
              "PHONE NUMBER (private — only you see this)",
              _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 25),
            _buildInputField("EMAIL", _emailController, enabled: false),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmDeleteAccount,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Permanently deletes your account and all data.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account, all your runs, posts, and data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _deleteAccountWithReauth(user);
  }

  /// Handles the full deletion flow including re-authentication when required.
  Future<void> _deleteAccountWithReauth(User user, {bool isRetry = false}) async {
    if (!mounted) return;

    // Show spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await AccountDeletionService().deleteAccount(userId: user.uid);
      if (!mounted) return;
      Navigator.pop(context); // dismiss spinner

      if (success) {
        await GoogleSignIn().signOut();
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showDeleteError();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss spinner

      if (e.code == 'requires-recent-login' && !isRetry) {
        await _reauthAndRetry(user);
      } else {
        _showDeleteError();
      }
    }
  }

  /// Prompts for re-authentication then retries deletion.
  Future<void> _reauthAndRetry(User user) async {
    final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');

    if (isGoogle) {
      await _reauthGoogle(user);
    } else {
      await _reauthPassword(user);
    }
  }

  Future<void> _reauthGoogle(User user) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null || !mounted) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      if (mounted) await _deleteAccountWithReauth(user, isRetry: true);
    } catch (_) {
      if (mounted) _showDeleteError();
    }
  }

  Future<void> _reauthPassword(User user) async {
    final passwordCtrl = TextEditingController();
    final reauthed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    passwordCtrl.dispose();
    if (reauthed != true || !mounted) return;

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      if (mounted) await _deleteAccountWithReauth(user, isRetry: true);
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password. Account not deleted.')),
        );
      }
    }
  }

  void _showDeleteError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete account. Please try again.')),
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

  Widget _buildInputField(String label, TextEditingController controller, {int maxLines = 1, bool enabled = true, IconData? icon, String? hint, TextInputType? keyboardType}) {
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
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
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