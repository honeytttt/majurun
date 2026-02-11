import '../entities/app_user.dart';

abstract class AuthRepository {
  /// Emits the current user (or null) whenever auth state changes.
  Stream<AppUser?> get onAuthStateChanged;

  // -------- Email / Password --------
  Future<AppUser?> signInWithEmail(String email, String password);

  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String gender,
    required String phoneNumber,
  });

  // -------- Phone (send & confirm) --------
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  });

  Future<AppUser?> signInWithOtp({
    required String verificationId,
    required String smsCode,
  });

  // -------- Phone: Link to existing user --------
  Future<void> linkPhoneNumber({
    required String verificationId,
    required String smsCode,
  });

  // -------- Other providers / sessions --------
  Future<AppUser?> signInWithGoogle();
  Future<AppUser?> signInWithFacebook();
  Future<AppUser?> signInAsGuest();
  Future<void> signOut();
}