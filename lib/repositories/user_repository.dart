import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';

/// Firestore CRUD for user profiles
/// Collection: users/{uid}
class UserRepository {
  final FirebaseFirestore _db;

  UserRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Get user profile from Firestore
  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromJson(doc.data()!);
  }

  /// Save or update user profile in Firestore
  Future<void> saveProfile(String uid, UserProfile profile) async {
    await _users.doc(uid).set(
      {
        ...profile.toJson(),
        'uid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Create initial profile doc (first login)
  Future<void> createProfile({
    required String uid,
    required String? email,
    required String? displayName,
    required UserProfile localProfile,
  }) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) return; // Don't overwrite existing

    await _users.doc(uid).set({
      ...localProfile.toJson(),
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update specific fields
  Future<void> updateFields(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete user profile
  Future<void> deleteProfile(String uid) async {
    await _users.doc(uid).delete();
  }

  /// Listen to profile changes (real-time)
  Stream<UserProfile?> profileStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromJson(doc.data()!);
    });
  }
}

/// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

/// Stream of current user's Firestore profile
final firestoreProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).profileStream(user.uid);
});
