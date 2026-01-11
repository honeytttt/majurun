import 'package:equatable/equatable.dart';

// We use Equatable to make comparing users easy (important for performance)
class UserEntity extends Equatable {
  final String uid;
  final String displayName;
  final String email;
  final String bio;
  final String photoUrl;
  final int followersCount;
  final int followingCount;
  final int postCount;

  const UserEntity({
    required this.uid,
    required this.displayName,
    required this.email,
    this.bio = '',
    this.photoUrl = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
  });

  @override
  List<Object?> get props => [uid, displayName, email, bio, photoUrl];
}