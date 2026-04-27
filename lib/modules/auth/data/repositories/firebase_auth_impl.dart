import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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
          // Do NOT auto-sign-in here. The signup flow requires additional steps
          // after phone verification (linking email + writing Firestore profile).
          // Calling signInWithCredential here consumes the verification session,
          // which makes the subsequent manual OTP entry fail with "session-expired".
          // For test numbers Firebase also fires this instantly before the OTP
          // screen is even shown — same problem.
          debugPrint("Auto-verification available — skipping auto sign-in, user will complete OTP manually");
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
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      // Email verification is encouraged but not mandatory — users can sign in
      // and verify later. The UI shows a gentle reminder snackbar if unverified.
      return _mapUser(cred.user);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'No account found for this email address.';
        case 'wrong-password':
        case 'invalid-credential':
          throw 'invalid-credential'; // login_screen maps this to the credentials sheet
        case 'too-many-requests':
          throw 'Too many sign-in attempts. Please wait a moment and try again.';
        case 'user-disabled':
          throw 'This account has been disabled. Please contact support.';
        default:
          throw e.message ?? 'Sign-in failed: ${e.code}';
      }
    }
  }

  @override
  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = cred.user!;
      // ActionCodeSettings prevents Gmail's link scanner from consuming the
      // verification token before the user taps it (fixes "link already expired").
      await user.sendEmailVerification(ActionCodeSettings(
        url: 'https://majurun-8d8b5.firebaseapp.com',
        handleCodeInApp: false,
        iOSBundleId: 'com.majurun.app',
        androidPackageName: 'com.majurun.app',
        androidInstallApp: true,
        androidMinimumVersion: '21',
      ));
      debugPrint("Email account created for UID: ${user.uid}");
      return _mapUser(user);
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth exception during signup: ${e.code} - ${e.message}");
      if (e.code == 'email-already-in-use') {
        throw "This email is already registered. Please sign in or reset your password.";
      }
      throw e.message ?? "Signup failed: ${e.code}";
    } catch (e) {
      debugPrint("Unexpected error during signup: $e");
      rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      // iOS needs explicit clientId because GoogleService-Info.plist is
      // gitignored and injected only in CI. On Android, clientId must be
      // null — the correct client ID is read automatically from
      // google-services.json. Passing an iOS clientId on Android causes
      // sign_in_failed PlatformException.
      clientId: (!kIsWeb && Platform.isIOS)
          ? '648836412000-iustsqi2f7i95liauoe6dbaqrj4kc0pg.apps.googleusercontent.com'
          : null,
      scopes: ['email', 'profile'],
    );
    // Sign out first to clear cached account and force account picker every time
    await googleSignIn.signOut();
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
        // Minimal doc — OnboardingScreen will complete the profile (dob, gender, name)
        await _db.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email ?? '',
          'photoUrl': userCredential.user!.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    return _mapUser(userCredential.user);
  }

  @override
  Future<AppUser?> signInWithFacebook() async => throw UnimplementedError();

  @override
  Future<AppUser?> signInWithTwitter() async {
    final twitterProvider = TwitterAuthProvider();

    try {
      // signInWithProvider handles mobile OAuth via browser; signInWithPopup is web-only
      final userCredential = await _auth.signInWithProvider(twitterProvider);
      
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

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // ActionCodeSettings ensures the reset link routes back to the app on
      // both iOS and Android, and prevents Gmail's link scanner from consuming
      // the token before the user taps it.
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://majurun-8d8b5.firebaseapp.com',
        handleCodeInApp: false,
        iOSBundleId: 'com.majurun.app',
        androidPackageName: 'com.majurun.app',
        androidInstallApp: true,
        androidMinimumVersion: '21',
      );
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: actionCodeSettings,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          throw 'No account found for this email address.';
        case 'too-many-requests':
          throw 'Too many requests. Please wait a moment and try again.';
        default:
          throw e.message ?? 'Failed to send reset email. Please try again.';
      }
    }
  }
}