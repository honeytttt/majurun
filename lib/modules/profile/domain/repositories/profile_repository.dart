import 'dart:typed_data';
import '../entities/user_entity.dart';

abstract class ProfileRepository {
  // Standardized upload method
  Future<String> uploadImage(Uint8List imageBytes);
  
  Stream<UserEntity?> streamUser(String uid);
  Stream<List<String>> streamFollowingIds(String uid);
  Future<void> updateProfile(UserEntity user);
  Future<void> toggleFollow(String currentUserId, String targetUserId);
  Stream<bool> isFollowing(String currentUserId, String targetUserId);
}