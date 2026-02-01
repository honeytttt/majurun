import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/profile/domain/entities/user_entity.dart';
import 'package:majurun/modules/profile/domain/repositories/profile_repository.dart';

class FirestoreProfileImpl implements ProfileRepository {
  final FirebaseFirestore _firestore;

  FirestoreProfileImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserEntity?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserEntity.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> createUser(UserEntity user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  @override
  Stream<UserEntity?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserEntity.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Future<void> updateProfile(UserEntity user) async {
    await _firestore.collection('users').doc(user.uid).update(user.toMap());
  }
}