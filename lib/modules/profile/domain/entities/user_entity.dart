import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String photoUrl;
  final String bio;
  final int postCount;
  final int followersCount;
  final int followingCount;

  const UserEntity({
    required this.id,
    required this.name,
    this.email = '',
    this.photoUrl = '',
    this.bio = '',
    this.postCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  String get uid => id;
  String get displayName => name;

  @override
  List<Object?> get props => [id, name, email, photoUrl, bio, postCount, followersCount, followingCount];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'postCount': postCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }

  factory UserEntity.fromMap(Map<String, dynamic> map, String docId) {
    return UserEntity(
      id: docId,
      name: map['name'] ?? map['displayName'] ?? 'User',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      bio: map['bio'] ?? '',
      postCount: map['postCount'] ?? 0,
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
    );
  }
}