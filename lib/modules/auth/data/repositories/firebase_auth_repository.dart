import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseAuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Replace with your actual Web Client ID from Firebase Console
  static const String _webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  late final GoogleSignIn _googleSignIn;

  FirebaseAuthRepository() {
    _googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? _webClientId : null,
    );
  }

  // Stream to track auth state (logged in vs logged out)
  Stream<User?> get userStream => _auth.authStateChanges();

  // --- EMAIL SIGN IN ---
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "An error occurred during email sign-in.");
    }
  }

  // --- GOOGLE SIGN IN ---
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
      rethrow;
    }
  }

  // --- FACEBOOK SIGN IN ---
  Future<UserCredential?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.token);
        return await _auth.signInWithCredential(credential);
      }
      return null;
    } catch (e) {
      print("Facebook Sign-In Error: $e");
      rethrow;
    }
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn.signOut();
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }
}