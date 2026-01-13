import 'package:equatable/equatable.dart';

class UserEntity {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final int postCount;
  final List<String> followers;
  final List<String> following;

  UserEntity({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    this.postCount = 0,
    this.followers = const [],
    this.following = const [],
  });

  factory UserEntity.fromMap(String id, Map<String, dynamic> map) {
    return UserEntity(
      uid: id,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      postCount: map['postCount'] ?? 0,
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'postCount': postCount,
      'followers': followers,
      'following': following,
    };
  }
}