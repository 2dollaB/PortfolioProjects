import 'package:cloud_firestore/cloud_firestore.dart';

/// Global cross-phone registry that guarantees exactly one BeatSync user per
/// HR strap. Keyed by the strap's advertised name (stable across phones —
/// unlike the per-central remoteId, which iOS randomises), so any client can
/// tell that a strap is already in use before it connects and hijacks it.
class StrapClaimRepository {
  StrapClaimRepository._();

  static final CollectionReference<Map<String, dynamic>> _claims =
      FirebaseFirestore.instance.collection('strap_claims');

  /// A claim is treated as abandoned once its heartbeat is older than this —
  /// covers crashes / force-quits where [release] never ran. Must match the
  /// same window in firestore.rules.
  static const Duration staleAfter = Duration(seconds: 45);

  static String _key(String strapName) => strapName.replaceAll('/', '_');

  /// Atomically claims [strapName] for [uid]. Returns true when the strap is
  /// now ours (was free, already ours, or the prior claim went stale), false
  /// when a different, still-alive user holds it.
  static Future<bool> tryClaim({
    required String strapName,
    required String uid,
    required String userName,
  }) {
    final ref = _claims.doc(_key(strapName));
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final d = snap.data()!;
        final owner = d['uid'] as String?;
        final hb = (d['heartbeat'] as Timestamp?)?.toDate();
        final fresh = hb != null && DateTime.now().difference(hb) < staleAfter;
        if (owner != uid && fresh) return false;
      }
      tx.set(ref, {
        'uid': uid,
        'name': userName,
        'claimedAt': FieldValue.serverTimestamp(),
        'heartbeat': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  /// Keeps our claim alive; call on a timer while connected.
  static Future<void> heartbeat(String strapName) async {
    try {
      await _claims.doc(_key(strapName)).update({
        'heartbeat': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Releases our claim on disconnect so the strap is immediately free again.
  static Future<void> release(String strapName) async {
    try {
      await _claims.doc(_key(strapName)).delete();
    } catch (_) {}
  }
}
