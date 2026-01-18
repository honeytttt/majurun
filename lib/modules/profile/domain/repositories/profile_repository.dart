import 'package:majurun/modules/profile/domain/entities/user_entity.dart';

abstract class ProfileRepository {
  Future<UserEntity?> getUser(String uid);
  Future<void> createUser(UserEntity user);
  Stream<UserEntity?> streamUser(String uid);
  Future<void> updateProfile(UserEntity user);
}