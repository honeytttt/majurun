import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';

class FirebaseProfileRepository implements ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<UserEntity?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      return UserEntity(
        uid: uid,
        displayName: data['displayName'] ?? '',
        email: data['email'] ?? '',
        bio: data['bio'] ?? '',
        photoUrl: data['photoUrl'] ?? '',
        followersCount: data['followersCount'] ?? 0,
        followingCount: data['followingCount'] ?? 0,
        postCount: data['postCount'] ?? 0,
      );
    });
  }

  @override
  Future<void> updateProfile(UserEntity user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'displayName': user.displayName,
      'bio': user.bio,
      'photoUrl': user.photoUrl,
      // Use Set with Merge to avoid overwriting other fields
    }, SetOptions(merge: true));
  }
}