import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<UserCredential?> signUp(String email, String password, String name) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      // Initialize the MajuRun Profile document atomically
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'displayName': name,
        'email': email,
        'bio': 'Moving forward with MajuRun! 🏃',
        'photoUrl': '',
        'followersCount': 0,
        'followingCount': 0,
        'postCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return credential;
  }

  @override
  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}