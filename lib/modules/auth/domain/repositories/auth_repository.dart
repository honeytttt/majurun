import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  // Use 'get' to define this as a stream property
  Stream<User?> get authStateChanges;
  
  Future<UserCredential> signIn(String email, String password);
  Future<UserCredential> signUp(String email, String password, String name);
  Future<void> signOut();
}