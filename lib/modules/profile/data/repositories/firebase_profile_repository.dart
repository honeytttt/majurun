import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:typed_data';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/entities/user_entity.dart';

class FirebaseProfileRepository implements ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Replace with your actual Cloudinary credentials
  final cloudinary = CloudinaryPublic('your_cloud_name', 'your_upload_preset', cache: false);

  @override
  Future<String> uploadImage(Uint8List imageBytes) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          imageBytes,
          identifier: 'img_${DateTime.now().millisecondsSinceEpoch}',
          folder: 'majurun_uploads',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception("Cloudinary Upload Failed: $e");
    }
  }

  @override
  Stream<UserEntity?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserEntity.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Stream<List<String>> streamFollowingIds(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data();
      return List<String>.from(data?['following'] ?? []);
    });
  }

  @override
  Future<void> updateProfile(UserEntity user) async {
    await _firestore.collection('users').doc(user.uid).update(user.toMap());
  }

  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    final currentUserDoc = _firestore.collection('users').doc(currentUserId);
    final targetUserDoc = _firestore.collection('users').doc(targetUserId);

    final doc = await currentUserDoc.get();
    final List following = doc.data()?['following'] ?? [];

    if (following.contains(targetUserId)) {
      await currentUserDoc.update({'following': FieldValue.arrayRemove([targetUserId])});
      await targetUserDoc.update({'followers': FieldValue.arrayRemove([currentUserId])});
    } else {
      await currentUserDoc.update({'following': FieldValue.arrayUnion([targetUserId])});
      await targetUserDoc.update({'followers': FieldValue.arrayUnion([currentUserId])});
    }
  }

  @override
  Stream<bool> isFollowing(String currentUserId, String targetUserId) {
    return _firestore.collection('users').doc(currentUserId).snapshots().map((doc) {
      final List following = doc.data()?['following'] ?? [];
      return following.contains(targetUserId);
    });
  }
}