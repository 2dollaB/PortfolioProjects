import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

/// Reads/writes the `users/{uid}` document. The Firestore doc id is the
/// Firebase UID, so [UserProfile.id] always mirrors the auth uid here.
class UserRepository {
  UserRepository._();

  static final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');

  static Future<UserProfile?> load(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return UserProfile.fromJson({...data, 'id': uid});
  }

  /// Loads several profiles at once (trainer member list). Docs that are
  /// missing or unreadable are skipped rather than failing the whole batch.
  static Future<List<UserProfile>> loadMany(List<String> uids) async {
    final results = await Future.wait(uids.map((uid) async {
      try {
        return await load(uid);
      } catch (_) {
        return null;
      }
    }));
    return results.whereType<UserProfile>().toList();
  }

  static Stream<UserProfile?> watch(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : UserProfile.fromJson({...data, 'id': uid});
    });
  }

  /// First write after profile setup — stamps the server createdAt once.
  static Future<void> create(String uid, UserProfile profile) async {
    await _users.doc(uid).set({
      ...profile.toJson(),
      'id': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Merge-update existing fields (edit profile, set studioId) without
  /// disturbing createdAt.
  static Future<void> update(String uid, UserProfile profile) async {
    await _users.doc(uid).set(
          {...profile.toJson(), 'id': uid},
          SetOptions(merge: true),
        );
  }

  /// Sets just the user's studioId (after joining a studio).
  static Future<void> setStudioId(String uid, String studioId) async {
    await _users.doc(uid).set({'studioId': studioId}, SetOptions(merge: true));
  }
}
