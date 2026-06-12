import 'package:flutter/foundation.dart';
import 'user_repository.dart';

/// Resolves uids → display names with caching. Used by the live boards
/// (trainer monitor, TV) whose hr docs carry only uids.
class UidNameCache {
  final Map<String, String> _names = {};
  final Set<String> _requested = {};

  String nameFor(String uid) => _names[uid] ?? 'Athlete';

  /// Fetches any uids not seen before, then calls [onLoaded] (typically a
  /// setState) once their names are available.
  void ensure(Iterable<String> uids, VoidCallback onLoaded) {
    final missing = uids.where((u) => !_requested.contains(u)).toList();
    if (missing.isEmpty) return;
    _requested.addAll(missing);
    UserRepository.loadMany(missing).then((profiles) {
      for (final p in profiles) {
        _names[p.id] = p.name;
      }
      if (profiles.isNotEmpty) onLoaded();
    });
  }
}
