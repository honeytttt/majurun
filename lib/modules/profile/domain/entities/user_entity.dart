import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String photoUrl;
  final String bio;
  final int followers; // Changed from followersCount to match UI
  final int following; // Changed from followingCount to match UI

  const UserEntity({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.bio = '',
    this.followers = 0,
    this.following = 0,
  });

  // These getters fix the "uid/displayName isn't defined" errors in UI
  String get uid => id;
  String get displayName => name;

  @override
  List<Object?> get props => [id, name, photoUrl, bio, followers, following];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'bio': bio,
      'followers': followers,
      'following': following,
    };
  }

  factory UserEntity.fromMap(Map<String, dynamic> map, String documentId) {
    return UserEntity(
      id: documentId,
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      bio: map['bio'] ?? '',
      followers: map['followers'] ?? 0,
      following: map['following'] ?? 0,
    );
  }
}