import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/user_entity.dart';
import '../domain/repositories/profile_repository.dart';

class FirebaseProfileRepository implements ProfileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<UserEntity> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) throw Exception("User not found");
      return UserEntity.fromMap(doc.data()!, documentId: doc.id);
    });
  }

  @override
  Future<UserEntity?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserEntity.fromMap(doc.data()!, documentId: doc.id) : null;
  }

  @override
  Future<void> updateProfile(UserEntity user) async {
    await _db.collection('users').doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  @override
  Stream<bool> isFollowing(String currentUserId, String targetUserId) {
    return _db
        .collection('following')
        .doc(currentUserId)
        .collection('userFollowing')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    final followingRef = _db.collection('following').doc(currentUserId).collection('userFollowing').doc(targetUserId);
    final doc = await followingRef.get();

    if (doc.exists) {
      await followingRef.delete();
    } else {
      await followingRef.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  @override
  Stream<List<String>> streamFollowingIds(String userId) {
    return _db.collection('following').doc(userId).collection('userFollowing').snapshots().map(
          (snap) => snap.docs.map((doc) => doc.id).toList(),
        );
  }

  @override
  Future<String> uploadImage(dynamic imageFile) async {
    // Implement Cloudinary/Firebase Storage logic here
    return "image_url";
  }
}