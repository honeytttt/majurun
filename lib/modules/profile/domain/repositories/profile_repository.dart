import 'dart:typed_data';
import '../entities/user_entity.dart';

abstract class ProfileRepository {
  Stream<UserEntity?> streamUser(String uid);
  Future<UserEntity?> getUserProfile(String uid);
  Future<void> updateProfile(UserEntity user);
  Future<String> uploadImage(Uint8List imageBytes);
  Stream<bool> isFollowing(String currentUid, String targetUid);
  Future<void> toggleFollow(String currentUid, String targetUid);
}