import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  // Stream to listen to user login state
  Stream<User?> get authStateChanges;
  
  // Sign Up
  Future<UserCredential?> signUp(String email, String password, String name);
  
  // Login
  Future<UserCredential?> signIn(String email, String password);
  
  // Sign Out
  Future<void> signOut();
}