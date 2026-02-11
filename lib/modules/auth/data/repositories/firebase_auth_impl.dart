import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
// REMOVED unused import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  // Web-only: cache ConfirmationResult by verificationId
  final Map<String, ConfirmationResult> _webConfirmations = {};

  FirebaseAuthImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<AppUser?> get onAuthStateChanged =>
      _auth.authStateChanges().map(_mapUser);

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isGuest: user.isAnonymous,
    );
  }

  // ---------------- PHONE: SEND CODE ----------------
  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    try {
      if (kIsWeb) {
        // ✅ SIMPLE - No RecaptchaVerifier needed for v2
        try {
          final confirmation = await _auth.signInWithPhoneNumber(
            phoneNumber.trim()
          );

          final verificationId = confirmation.verificationId;
          _webConfirmations[verificationId] = confirmation;
          
          onCodeSent(verificationId);
          
        } catch (e) {
          onError('Failed to send code: ${e.toString()}');
        }
        return;
      }

      // ANDROID / iOS path
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval on Android
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed.');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // ---------------- PHONE: CONFIRM CODE (SIGN IN) ----------------
  @override
  Future<AppUser?> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (kIsWeb) {
      final confirmation = _webConfirmations[verificationId];
      if (confirmation == null) {
        throw StateError(
          'Missing ConfirmationResult. Please resend the code.',
        );
      }
      final userCred = await confirmation.confirm(smsCode);
      _webConfirmations.remove(verificationId);
      return _mapUser(userCred.user);
    } else {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCred = await _auth.signInWithCredential(credential);
      return _mapUser(userCred.user);
    }
  }

  // ---------------- PHONE: LINK TO EXISTING USER ----------------
  @override
  Future<void> linkPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final currentUser = _auth.currentUser;
      
      if (currentUser == null) {
        final userCred = await _auth.signInWithCredential(credential);
        if (userCred.user == null) {
          throw 'Failed to link phone number';
        }
      } else {
        await currentUser.linkWithCredential(credential);
      }
      
      final user = _auth.currentUser;
      if (user != null && user.phoneNumber != null) {
        await _db.collection('users').doc(user.uid).update({
          'phoneNumber': user.phoneNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw 'This phone number is already linked to another account.';
      } else {
        throw e.message ?? 'Failed to link phone number.';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // ---------------- EMAIL/PASSWORD ----------------
  @override
  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      if (!cred.user!.emailVerified && !cred.user!.isAnonymous) {
        await cred.user!.sendEmailVerification();
        throw 'Please verify your email link sent to $email.';
      }
      return _mapUser(cred.user);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Sign in failed';
    }
  }

  @override
  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String gender,
    required String phoneNumber,
  }) async {
    try {
      UserCredential cred;
      if (_auth.currentUser != null) {
        final emailAuth =
            EmailAuthProvider.credential(email: email, password: password);
        cred = await _auth.currentUser!.linkWithCredential(emailAuth);
      } else {
        cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
      }

      if (cred.user != null) {
        await _db.collection('users').doc(cred.user!.uid).set(
          {
            'firstName': firstName,
            'lastName': lastName,
            'displayName': '$firstName $lastName',
            'email': email,
            'dob': dob.toIso8601String(),
            'gender': gender,
            'phoneNumber': phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'workoutsCount': 0,
            'totalKm': 0.0,
            'totalRunSeconds': 0,
            'totalCalories': 0,
            'postsCount': 0,
            'followersCount': 0,
            'followingCount': 0,
            'badge5k': 0,
            'badge10k': 0,
            'badgeHalf': 0,
            'badgeFull': 0,
          },
          SetOptions(merge: true),
        );
        await cred.user!.updateDisplayName('$firstName $lastName');
      }
      return _mapUser(cred.user);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Signup failed';
    }
  }

  // ---------------- OTHER PROVIDERS ----------------
  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return _mapUser(userCredential.user);
    } catch (e) {
      throw 'Google sign in failed: ${e.toString()}';
    }
  }

  @override
  Future<AppUser?> signInWithFacebook() async =>
      throw UnimplementedError('Facebook sign in not implemented');

  @override
  Future<AppUser?> signInAsGuest() async {
    try {
      final cred = await _auth.signInAnonymously();
      return _mapUser(cred.user);
    } catch (e) {
      throw 'Guest sign in failed: ${e.toString()}';
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        _webConfirmations.clear();
      }
      await GoogleSignIn().signOut();
      await _auth.signOut();
    } catch (e) {
      // Ignore sign out errors
    }
  }
}