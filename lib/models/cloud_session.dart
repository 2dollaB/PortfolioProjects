import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-side view of a `sessions/{id}` doc — a cloud group session hosted by
/// the studio's trainer. (Write side lives in SessionRepository.)
class CloudSession {
  final String id;
  final String studioId;
  final String trainerUid;
  final String name;
  final String type; // workout type enum name, e.g. 'hiit'
  final String status; // 'live' | 'ended'
  final DateTime startedAt;
  final DateTime? endedAt;

  const CloudSession({
    required this.id,
    required this.studioId,
    required this.trainerUid,
    required this.name,
    required this.type,
    required this.status,
    required this.startedAt,
    this.endedAt,
  });

  bool get isLive => status == 'live';

  Duration get duration =>
      (endedAt ?? DateTime.now()).difference(startedAt);

  factory CloudSession.fromDoc(String id, Map<String, dynamic> d) {
    DateTime ts(dynamic v) => v is Timestamp
        ? v.toDate()
        : DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return CloudSession(
      id: id,
      studioId: d['studioId'] as String? ?? '',
      trainerUid: d['trainerUid'] as String? ?? '',
      name: d['name'] as String? ?? 'Group session',
      type: d['type'] as String? ?? 'free',
      status: d['status'] as String? ?? 'ended',
      startedAt: ts(d['startedAt']),
      endedAt: d['endedAt'] == null ? null : ts(d['endedAt']),
    );
  }
}

/// One athlete's row on the live HR board (`sessions/{id}/hr/{uid}`).
class SessionHrEntry {
  final String uid;
  final int bpm;
  final int zone;
  final int hrMax;
  final DateTime lastUpdate;

  const SessionHrEntry({
    required this.uid,
    required this.bpm,
    required this.zone,
    required this.hrMax,
    required this.lastUpdate,
  });

  factory SessionHrEntry.fromDoc(String uid, Map<String, dynamic> d) {
    return SessionHrEntry(
      uid: uid,
      bpm: (d['bpm'] as num?)?.toInt() ?? 0,
      zone: (d['zone'] as num?)?.toInt() ?? 0,
      hrMax: (d['hrMax'] as num?)?.toInt() ?? 0,
      lastUpdate: d['lastUpdate'] is Timestamp
          ? (d['lastUpdate'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
