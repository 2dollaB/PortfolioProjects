import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// One-shot device-clock vs. Firestore-server-clock offset.
///
/// A group workout's synced 3-2-1 countdown compares each device's local
/// clock against a shared target instant (`CloudSession.runningSince`). Raw
/// `DateTime.now()` isn't reliable for that — two phones' clocks can differ
/// by a couple of seconds — so every device that cares about the countdown
/// (trainer host and each athlete) calls [sync] once, then reads "now" via
/// [now] wherever it would otherwise use `DateTime.now()` for that math.
class ClockSync {
  ClockSync._();

  static Duration _offset = Duration.zero;
  static bool _synced = false;
  static Future<void>? _inFlight;

  /// Best-effort server-corrected "now". Falls back to the raw device clock
  /// until [sync] completes (or if it never can — offline, signed out).
  static DateTime now() => DateTime.now().add(_offset);

  /// Writes a throwaway server-timestamped doc and diffs it against the local
  /// clock at the moment the server-confirmed value comes back. Cheap,
  /// idempotent — call it freely (e.g. on entering a session lobby); repeat
  /// calls before the first completes share the same in-flight request.
  static Future<void> sync() {
    if (_synced) return Future.value();
    return _inFlight ??= _doSync().whenComplete(() => _inFlight = null);
  }

  static Future<void> _doSync() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    try {
      final ref = FirebaseFirestore.instance.collection('clock_sync').doc(uid);
      await ref.set({'t': FieldValue.serverTimestamp()});
      final localNow = DateTime.now();
      final snap = await ref.get(const GetOptions(source: Source.server));
      final serverTime = (snap.data()?['t'] as Timestamp?)?.toDate();
      if (serverTime != null) {
        _offset = serverTime.difference(localNow);
        _synced = true;
      }
      unawaited(ref.delete().catchError((_) {}));
    } catch (_) {
      // Offline or blocked — keep using the raw device clock.
    }
  }
}
