import '../entities/user_entity.dart';

abstract class ProfileRepository {
  Stream<UserEntity?> streamUser(String uid);
  Future<void> updateProfile(UserEntity user);
}