import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';

class FirebaseProfileRepository implements ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Stream<UserEntity?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) =>
        doc.exists ? UserEntity.fromMap(doc.data()!, doc.id) : null);
  }

  @override
  Future<UserEntity?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? UserEntity.fromMap(doc.data()!, doc.id) : null;
  }

  @override
  Future<void> updateProfile(UserEntity user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  @override
  Future<String> uploadImage(Uint8List imageBytes) async {
    final ref = _storage.ref().child('profiles/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(imageBytes);
    return await ref.getDownloadURL();
  }

  @override
  Stream<bool> isFollowing(String currentUid, String targetUid) {
    return _firestore.collection('users').doc(currentUid).snapshots().map((doc) {
      final following = List<String>.from(doc.data()?['following'] ?? []);
      return following.contains(targetUid);
    });
  }

  @override
  Future<void> toggleFollow(String currentUid, String targetUid) async {
    final userRef = _firestore.collection('users').doc(currentUid);
    final targetRef = _firestore.collection('users').doc(targetUid);
    
    final doc = await userRef.get();
    final following = List<String>.from(doc.data()?['following'] ?? []);

    if (following.contains(targetUid)) {
      await userRef.update({'following': FieldValue.arrayRemove([targetUid])});
      await targetRef.update({'followers': FieldValue.arrayRemove([currentUid])});
    } else {
      await userRef.update({'following': FieldValue.arrayUnion([targetUid])});
      await targetRef.update({'followers': FieldValue.arrayUnion([currentUid])});
    }
  }
}