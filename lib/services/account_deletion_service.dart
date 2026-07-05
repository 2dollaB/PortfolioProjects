import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Full account deletion (Apple/Google review requirement + GDPR).
///
/// Re-authenticates with the user's password first (Firebase refuses to
/// delete an auth user without a recent login), then wipes their Firestore
/// footprint, then deletes the auth user — which signs them out through the
/// auth stream. Throws [FirebaseAuthException] on a wrong password.
class AccountDeletionService {
  AccountDeletionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> deleteAccount({required String password}) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No signed-in email user');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );

    final uid = user.uid;

    // Own workouts.
    final workouts = await _db
        .collection('workouts')
        .where('userId', isEqualTo: uid)
        .get();
    for (final d in workouts.docs) {
      await d.reference.delete();
    }

    // Membership studio id (may be an owned studio for trainers).
    final profileDoc = await _db.collection('users').doc(uid).get();
    final studioId = profileDoc.data()?['studioId'] as String?;

    // Owned studios (trainer): sessions, invite-code lookup, studio doc.
    // The invite code must go before its studio — its delete rule reads the
    // studio doc to verify ownership. Old sessions' hr subdocs are left
    // behind (subcollections aren't cascade-deleted); they hold only bpm
    // samples keyed by a uid that no longer resolves.
    final owned =
        await _db.collection('studios').where('ownerUid', isEqualTo: uid).get();
    for (final s in owned.docs) {
      final sessions = await _db
          .collection('sessions')
          .where('studioId', isEqualTo: s.id)
          .get();
      for (final sess in sessions.docs) {
        await sess.reference.delete();
      }
      final code = s.data()['inviteCode'] as String?;
      if (code != null && code.isNotEmpty) {
        try {
          await _db.collection('invite_codes').doc(code).delete();
        } catch (_) {/* lookup may already be gone */}
      }
      await s.reference.delete();
    }

    // Athlete membership in someone else's studio: self-leave.
    if (studioId != null && owned.docs.every((d) => d.id != studioId)) {
      try {
        await _db.collection('studios').doc(studioId).update({
          'memberUids': FieldValue.arrayRemove([uid]),
        });
      } catch (_) {/* studio may no longer exist */}
    }

    await _db.collection('users').doc(uid).delete();

    // Last — this signs the user out via the auth stream.
    await user.delete();
  }
}
