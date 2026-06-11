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

  /// Emits on sign-in / sign-out — the AuthGate listens to this.
  static Stream<User?> authStateChanges() => _auth.authStateChanges();

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
