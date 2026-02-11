import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? "Verification failed.");
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
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
      UserCredential cred;
      // Link email to the phone session already active
      if (_auth.currentUser != null) {
        final emailAuth = EmailAuthProvider.credential(email: email, password: password);
        cred = await _auth.currentUser!.linkWithCredential(emailAuth);
      } else {
        cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password.trim());
      }
      
      if (cred.user != null) {
        await cred.user!.sendEmailVerification();
        await _db.collection('users').doc(cred.user!.uid).set({
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
        
        await cred.user!.updateDisplayName("$firstName $lastName");
      }
      return _mapUser(cred.user);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Signup failed";
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
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
  Future<AppUser?> signInAsGuest() async {
    try {
      final cred = await _auth.signInAnonymously();
      return _mapUser(cred.user);
    } catch (e) {
      throw "Guest sign-in failed: $e";
    }
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}