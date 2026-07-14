import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Phone ⇄ TV pairing over a short numeric code.
///
/// The TV (web board, anonymous auth) calls [createForTv] to publish a
/// `tv_sessions/{code}` doc carrying its own uid and shows the code. The
/// trainer's phone calls [pair] with that code: it stamps the studioId onto
/// the doc and adds the TV's anon uid to `studios/{id}.tvUids`, which the
/// Firestore rules read to grant that TV board-read access. The TV watches
/// its doc via [watch] and, once `studioId` lands, renders the board.
class TvPairingRepository {
  TvPairingRepository._();

  static final CollectionReference<Map<String, dynamic>> _tvSessions =
      FirebaseFirestore.instance.collection('tv_sessions');
  static final CollectionReference<Map<String, dynamic>> _studios =
      FirebaseFirestore.instance.collection('studios');

  /// TV side: create a fresh pairing doc owned by [tvUid] and return the code
  /// the athlete-facing screen should display. Retries on the (rare) collision
  /// with an existing unpaired code.
  static Future<String> createForTv(String tvUid) async {
    final rng = math.Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(4, (_) => rng.nextInt(10)).join();
      final ref = _tvSessions.doc(code);
      final existing = await ref.get();
      // Only claim a free code (create-only keeps us within the rules, which
      // let a later update change just studioId).
      if (existing.exists) continue;
      await ref.set({
        'tvUid': tvUid,
        'studioId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return code;
    }
    throw StateError('Could not allocate a TV code');
  }

  /// TV side: stream the pairing doc so the board appears the moment the
  /// phone stamps a studioId onto it.
  static Stream<TvPairing?> watch(String code) {
    return _tvSessions.doc(code).snapshots().map((d) {
      final data = d.data();
      if (!d.exists || data == null) return null;
      return TvPairing(
        code: d.id,
        tvUid: data['tvUid'] as String? ?? '',
        studioId: data['studioId'] as String?,
      );
    });
  }

  /// Phone side: link [code] to [studioId]. Grants the TV's uid board-read on
  /// the studio, then points the pairing doc at the studio so the TV picks it
  /// up. Returns null on success or a short error reason.
  static Future<String?> pair({
    required String code,
    required String studioId,
  }) async {
    final ref = _tvSessions.doc(code.trim());
    final snap = await ref.get();
    final tvUid = snap.data()?['tvUid'] as String?;
    if (!snap.exists || tvUid == null) return 'noCode';
    // Grant read first (rules gate the TV's board reads on this), then stamp
    // the studio so the TV only starts reading once it's allowed to.
    await _studios.doc(studioId).update({
      'tvUids': FieldValue.arrayUnion([tvUid]),
    });
    await ref.update({'studioId': studioId});
    return null;
  }
}

class TvPairing {
  final String code;
  final String tvUid;
  final String? studioId;
  const TvPairing({required this.code, required this.tvUid, this.studioId});

  bool get isPaired => studioId != null && studioId!.isNotEmpty;
}
