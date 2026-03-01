import 'package:beatsync/config/hr_zones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HrZones', () {
    test('Tanaka formula calculates correctly', () {
      // Age 30: 208 - (0.7 * 30) = 187
      expect(HrZones.tanaka(30), 187);
      // Age 40: 208 - (0.7 * 40) = 180
      expect(HrZones.tanaka(40), 180);
    });

    test('Zone calculation from BPM', () {
      const hrMax = 187;
      // 90 BPM = 48% → Zone 0 (Rest)
      expect(HrZones.fromBpm(90, hrMax), 0);
      // 100 BPM = 53% → Zone 1
      expect(HrZones.fromBpm(100, hrMax), 1);
      // 120 BPM = 64% → Zone 2
      expect(HrZones.fromBpm(120, hrMax), 2);
      // 140 BPM = 74% → Zone 3
      expect(HrZones.fromBpm(140, hrMax), 3);
      // 160 BPM = 85% → Zone 4
      expect(HrZones.fromBpm(160, hrMax), 4);
      // 175 BPM = 93% → Zone 5
      expect(HrZones.fromBpm(175, hrMax), 5);
    });
  });
}
