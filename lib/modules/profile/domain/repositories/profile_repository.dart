import '../entities/user_entity.dart';

abstract class ProfileRepository {
  // Real-time updates for UI
  Stream<UserEntity> streamUser(String uid);
  
  // Single fetch
  Future<UserEntity?> getUser(String uid);
  
  Future<void> updateProfile(UserEntity user);
  Future<void> toggleFollow(String currentUserId, String targetUserId);
  Stream<List<String>> streamFollowingIds(String userId);
  
  // Note: UI expects a Stream here in user_profile_screen.dart:157
  Stream<bool> isFollowing(String currentUserId, String targetUserId);
  
  Future<String> uploadImage(dynamic imageFile);
}