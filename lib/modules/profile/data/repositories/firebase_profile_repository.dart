import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';

class FirebaseProfileRepository implements ProfileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<UserEntity> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      return UserEntity.fromMap(doc.data() ?? {}, doc.id);
    });
  }

  @override
  Future<UserEntity?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserEntity.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> updateProfile(UserEntity user) async {
    await _db.collection('users').doc(user.id).update(user.toMap());
  }

  @override
  Future<String> uploadImage(dynamic imageFile) async {
    // Implement your Cloudinary or Firebase Storage logic here
    return ""; 
  }

  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    // Follow logic
  }

  @override
  Stream<List<String>> streamFollowingIds(String userId) {
    return Stream.value([]);
  }

  @override
  Stream<bool> isFollowing(String currentUserId, String targetUserId) {
    return Stream.value(false);
  }
}