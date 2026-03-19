import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  FirebaseAuthImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<AppUser?> get onAuthStateChanged =>
      _auth.authStateChanges().map((user) => _mapUser(user));

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? "",
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isGuest: user.isAnonymous,
    );
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    debugPrint("verifyPhoneNumber called with phone: $phoneNumber");

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint("Auto-verification completed (instant verification)");
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint("Verification failed: ${e.code} - ${e.message}");
          onError(e.message ?? "Verification failed: ${e.code}");
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint("Code sent successfully - verificationId: $verificationId");
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint("Auto retrieval timeout: $verificationId");
        },
      );
    } catch (e) {
      debugPrint("Exception in verifyPhoneNumber: $e");
      onError("Phone verification exception: $e");
    }
  }

  @override
  Future<AppUser?> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return _mapUser(userCredential.user);
  }

  @override
  Future<AppUser?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password.trim());

    if (!cred.user!.emailVerified && !cred.user!.isAnonymous) {
      await cred.user!.sendEmailVerification();
      throw "Security: Please verify your email. A link has been sent to $email.";
    }
    return _mapUser(cred.user);
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
      User? user;

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Phone session already active → try to link email credential
        final emailAuth = EmailAuthProvider.credential(email: email, password: password);
        try {
          final cred = await currentUser.linkWithCredential(emailAuth);
          user = cred.user;
          debugPrint("Email credential linked successfully to existing user");
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked') {
            debugPrint("Email already linked to this user");
            user = currentUser;
          } else if (e.code == 'email-already-in-use') {
            debugPrint("Email already in use: ${e.message}");
            throw "This email is already registered with another account. Please sign in or use a different email.";
          } else {
            debugPrint("Linking error: ${e.code} - ${e.message}");
            rethrow;
          }
        }
      } else {
        debugPrint("No current user found - creating new email account");
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
        user = cred.user;
      }

      if (user == null) {
        throw "Authentication failed - no user returned after linking/creation";
      }

      // Send verification email
      await user.sendEmailVerification();

      // Safe Firestore write (merge = true)
      await _db.collection('users').doc(user.uid).set({
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
      }, SetOptions(merge: true));

      await user.updateDisplayName("$firstName $lastName");

      debugPrint("User profile created/updated for UID: ${user.uid}");

      return _mapUser(user);
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth exception during signup: ${e.code} - ${e.message}");
      throw e.message ?? "Signup failed: ${e.code}";
    } catch (e) {
      debugPrint("Unexpected error during signup: $e");
      throw "Unexpected error during signup: $e";
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    // Let google_sign_in auto-detect from google-services.json
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
    );
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final UserCredential userCredential = await _auth.signInWithCredential(credential);

    if (userCredential.user != null) {
      final userDoc = await _db.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        await _db.collection('users').doc(userCredential.user!.uid).set({
          'displayName': userCredential.user!.displayName ?? 'Runner',
          'email': userCredential.user!.email ?? '',
          'photoUrl': userCredential.user!.photoURL ?? '',
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
        });
      }
    }
    return _mapUser(userCredential.user);
  }

  @override
  Future<AppUser?> signInWithFacebook() async => throw UnimplementedError();

  @override
  Future<AppUser?> signInWithTwitter() async {
    // Create a Twitter provider
    final twitterProvider = TwitterAuthProvider();
    
    try {
      // Sign in with popup (web) or redirect (mobile)
      final userCredential = await _auth.signInWithPopup(twitterProvider);
      
      if (userCredential.user != null) {
        // Check if user exists in Firestore
        final userDoc = await _db.collection('users').doc(userCredential.user!.uid).get();
        
        if (!userDoc.exists) {
          // Create new user document for Twitter sign-in
          await _db.collection('users').doc(userCredential.user!.uid).set({
            'displayName': userCredential.user!.displayName ?? 'Runner',
            'email': userCredential.user!.email ?? '',
            'photoUrl': userCredential.user!.photoURL ?? '',
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
          });
        }
      }
      
      return _mapUser(userCredential.user);
    } on FirebaseAuthException catch (e) {
      debugPrint("Twitter sign-in error: ${e.code} - ${e.message}");
      
      if (e.code == 'account-exists-with-different-credential') {
        throw "An account already exists with the same email address but different sign-in credentials.";
      } else if (e.code == 'provider-already-linked') {
        throw "Twitter account is already linked to another account.";
      }
      
      throw e.message ?? "Twitter sign-in failed";
    } catch (e) {
      debugPrint("Unexpected error during Twitter sign-in: $e");
      throw "Twitter sign-in failed: $e";
    }
  }

  @override
  Future<AppUser?> signInAsGuest() async {
    // REMOVED: Guest sign-in functionality - now throws unimplemented
    throw UnimplementedError("Guest sign-in has been disabled");
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}