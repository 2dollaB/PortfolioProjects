import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes/reads the `studios/{studioId}` collection. Invite-code lookup and
/// join flows arrive in the next increment; for now this just creates the
/// studio a trainer makes during onboarding.
class StudioRepository {
  StudioRepository._();

  static final CollectionReference<Map<String, dynamic>> _studios =
      FirebaseFirestore.instance.collection('studios');

  /// Creates a studio owned by [ownerUid]; returns the new studio id.
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
    return ref.id;
  }
}
