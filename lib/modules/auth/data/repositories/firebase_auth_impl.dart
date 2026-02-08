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
  Future<AppUser?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password.trim());
    
    // Check if email is verified if not a guest
    if (!cred.user!.emailVerified && !cred.user!.isAnonymous) {
      await cred.user!.sendEmailVerification();
      throw "Please verify your email. A link has been sent to $email.";
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
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      
      if (cred.user != null) {
        // 1. Send Verification Email
        await cred.user!.sendEmailVerification();

        // 2. Save to Firestore with initialized stats
        await _db.collection('users').doc(cred.user!.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'displayName': '$firstName $lastName',
          'email': email,
          'dob': dob.toIso8601String(),
          'gender': gender,
          'phoneNumber': phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'isEmailVerified': false,
          // Initialize stats fields
          'workoutsCount': 0,
          'totalKm': 0.0,
          'totalRunSeconds': 0,
          'totalCalories': 0,
          'postsCount': 0,
          'followersCount': 0,
          'followingCount': 0,
          // Initialize badge fields
          'badge5k': 0,
          'badge10k': 0,
          'badgeHalf': 0,
          'badgeFull': 0,
        });
        
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

    // Create/update user document for Google sign-in users
    if (userCredential.user != null) {
      final userDoc = await _db.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        // Create new user document with initialized stats
        await _db.collection('users').doc(userCredential.user!.uid).set({
          'displayName': userCredential.user!.displayName ?? 'Runner',
          'email': userCredential.user!.email ?? '',
          'photoUrl': userCredential.user!.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          // Initialize stats fields
          'workoutsCount': 0,
          'totalKm': 0.0,
          'totalRunSeconds': 0,
          'totalCalories': 0,
          'postsCount': 0,
          'followersCount': 0,
          'followingCount': 0,
          // Initialize badge fields
          'badge5k': 0,
          'badge10k': 0,
          'badgeHalf': 0,
          'badgeFull': 0,
        });
      } else {
        // Update existing doc with photo if missing
        final data = userDoc.data() ?? {};
        if (data['photoUrl'] == null || (data['photoUrl'] as String).isEmpty) {
          await _db.collection('users').doc(userCredential.user!.uid).set({
            'photoUrl': userCredential.user!.photoURL ?? '',
          }, SetOptions(merge: true));
        }
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