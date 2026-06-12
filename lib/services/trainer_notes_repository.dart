import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads/writes `trainer_notes/{trainerUid}/members/{memberUid}` — a
/// trainer's private note about one member. Rules keep it trainer-only.
class TrainerNotesRepository {
  TrainerNotesRepository._();

  static DocumentReference<Map<String, dynamic>> _doc(
          String trainerUid, String memberUid) =>
      FirebaseFirestore.instance
          .collection('trainer_notes')
          .doc(trainerUid)
          .collection('members')
          .doc(memberUid);

  /// The saved note, or '' if none yet.
  static Future<String> load(String trainerUid, String memberUid) async {
    final doc = await _doc(trainerUid, memberUid).get();
    return doc.data()?['text'] as String? ?? '';
  }

  static Future<void> save(
      String trainerUid, String memberUid, String text) {
    return _doc(trainerUid, memberUid).set({
      'text': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
