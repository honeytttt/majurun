import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String bio;
  final int followersCount;
  final int followingCount;

  const UserEntity({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.photoUrl = '',
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
  });

  factory UserEntity.fromMap(Map<String, dynamic> map, String id) {
    return UserEntity(
      uid: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      bio: map['bio'] ?? '',
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }

  @override
  List<Object?> get props => [uid, email];
}