import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<UserCredential> signIn(String email, String password);
  Future<UserCredential> signUp(String email, String password, String name);
  Future<void> signOut();
  Future<UserCredential> signInWithGoogle();
  Future<UserCredential> signInWithFacebook();
}