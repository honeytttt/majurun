import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from Gallery or Camera
  Future<File?> pickImage(ImageSource source) async {
    final XFile? selectedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70, // Compress for faster upload
    );
    return selectedFile != null ? File(selectedFile.path) : null;
  }

  /// Upload the file and return the URL
  Future<String> uploadUserImage(String userId, File file) async {
    final ref = _storage.ref().child('user_photos').child('$userId.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}