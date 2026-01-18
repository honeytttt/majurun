import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String bio;
  final int postCount;
  final List<String> followers;
  final List<String> following;

  const UserEntity({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl = '',
    this.bio = '',
    this.postCount = 0,
    this.followers = const [],
    this.following = const [],
  });

  // Fixes the 'undefined_named_parameter' and 'undefined_getter' errors
  int get followersCount => followers.length;
  int get followingCount => following.length;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'postCount': postCount,
      'followers': followers,
      'following': following,
    };
  }

  factory UserEntity.fromMap(Map<String, dynamic> map, String id) {
    return UserEntity(
      uid: id,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      bio: map['bio'] ?? '',
      postCount: map['postCount'] ?? 0,
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
    );
  }

  @override
  List<Object?> get props => [uid, displayName, email, photoUrl, bio, postCount, followers, following];
}