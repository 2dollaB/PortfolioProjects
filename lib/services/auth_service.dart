import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth (email/password only for MVP).
///
/// Auth methods return `null` on success or a human-readable error string,
/// so screens can show the message without knowing about Firebase error codes.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => _auth.currentUser?.uid;

  /// Whether the signed-in user has confirmed their email. Cached on the User
  /// object — call [reloadVerification] to pick up a link clicked elsewhere.
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Emits on sign-in / sign-out — the AuthGate listens to this.
  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Re-fetches the user so [isEmailVerified] reflects a verification link the
  /// user opened in their mail app (Firebase doesn't push that change live).
  static Future<bool> reloadVerification() async {
    try {
      await _auth.currentUser?.reload();
    } catch (_) {}
    return isEmailVerified;
  }

  /// Re-sends the verification email to the signed-in user.
  static Future<String?> resendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  /// Sends a password-reset email. Returns null on success or a message.
  /// A missing account is treated as success so we don't reveal which emails
  /// are registered.
  static Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return null;
      return _message(e);
    }
  }

  static Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  static Future<String?> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  static Future<void> signOut() => _auth.signOut();

  static String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error — check your connection.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled for this project yet.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
