import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes/reads the `studios/{studioId}` collection plus the `invite_codes`
/// lookup that lets athletes resolve a studio they don't yet belong to.
class StudioRepository {
  StudioRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _studios =
      _db.collection('studios');
  static final CollectionReference<Map<String, dynamic>> _inviteCodes =
      _db.collection('invite_codes');

  /// Creates a studio owned by [ownerUid] and its invite-code lookup entry;
  /// returns the new studio id.
  static Future<String> create({
    required String ownerUid,
    required String name,
    String? location,
    required int maxMembers,
    required String inviteCode,
  }) async {
    final ref = _studios.doc();
    await ref.set({
      'name': name,
      'location': location,
      'ownerUid': ownerUid,
      'inviteCode': inviteCode,
      'memberUids': [ownerUid],
      'maxMembers': maxMembers,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Lookup entry (rule checks the studio exists + is owned by caller, so this
    // must run after the studio write above).
    await _inviteCodes.doc(inviteCode).set({
      'studioId': ref.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Resolves a 6-digit invite code to a studio id, or null if unknown.
  static Future<String?> resolveStudioId(String code) async {
    final doc = await _inviteCodes.doc(code.trim()).get();
    return doc.data()?['studioId'] as String?;
  }

  /// Adds [uid] to a studio's member list (scoped self-join). The caller must
  /// then set their own users/{uid}.studioId.
  static Future<void> join({
    required String uid,
    required String studioId,
  }) async {
    await _studios.doc(studioId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
  }
}
