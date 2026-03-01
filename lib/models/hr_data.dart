/// Heart rate data point from BLE sensor
class HrData {
  final int bpm;
  final List<int> rrIntervals; // in milliseconds
  final DateTime timestamp;

  HrData({
    required this.bpm,
    this.rrIntervals = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Heart rate zone (1-5) based on percentage of HRmax
  static int zone(int bpm, int hrMax) {
    final pct = (bpm / hrMax * 100).round();
    if (pct < 50) return 0; // Below zone
    if (pct < 60) return 1; // Zone 1 - Very Light
    if (pct < 70) return 2; // Zone 2 - Light
    if (pct < 80) return 3; // Zone 3 - Moderate
    if (pct < 90) return 4; // Zone 4 - Hard
    return 5; // Zone 5 - Maximum
  }

  /// Zone name
  static String zoneName(int zone) {
    switch (zone) {
      case 0:
        return 'Rest';
      case 1:
        return 'Very Light';
      case 2:
        return 'Light';
      case 3:
        return 'Moderate';
      case 4:
        return 'Hard';
      case 5:
        return 'Maximum';
      default:
        return 'Unknown';
    }
  }
}
