/// Read-side view of a `studios/{id}` doc — what the trainer screens render.
/// (The write side lives in StudioRepository.create/join.)
class Studio {
  final String id;
  final String name;
  final String? location;
  final String ownerUid;
  final String inviteCode;
  final List<String> memberUids;
  final int maxMembers;

  const Studio({
    required this.id,
    required this.name,
    this.location,
    required this.ownerUid,
    required this.inviteCode,
    required this.memberUids,
    required this.maxMembers,
  });

  /// Members excluding the owning trainer (memberUids includes the owner).
  List<String> get athleteUids =>
      memberUids.where((u) => u != ownerUid).toList();

  factory Studio.fromDoc(String id, Map<String, dynamic> d) {
    return Studio(
      id: id,
      name: d['name'] as String? ?? 'My Studio',
      location: d['location'] as String?,
      ownerUid: d['ownerUid'] as String? ?? '',
      inviteCode: d['inviteCode'] as String? ?? '',
      memberUids:
          (d['memberUids'] as List?)?.whereType<String>().toList() ?? const [],
      maxMembers: (d['maxMembers'] as num?)?.toInt() ?? 0,
    );
  }
}
