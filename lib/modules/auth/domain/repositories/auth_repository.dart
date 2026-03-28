import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get onAuthStateChanged;

  Future<AppUser?> signInWithEmail(String email, String password);

  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  });

  Future<AppUser?> signInWithOtp({
    required String verificationId,
    required String smsCode,
  });

  Future<AppUser?> signInWithGoogle();
  Future<AppUser?> signInWithFacebook();
  Future<AppUser?> signInWithTwitter();
  Future<AppUser?> signInAsGuest();
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
}
