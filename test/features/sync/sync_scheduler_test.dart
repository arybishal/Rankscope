import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/features/sync/background/sync_workmanager.dart';

void main() {
  group('SyncScheduler Local Timezone Scheduling Tests', () {
    late SyncScheduler scheduler;

    setUp(() {
      scheduler = SyncScheduler();
    });

    test('computeNextScheduleTime returns 8:00 AM today if current time is before 8:00 AM', () {
      final now = DateTime(2026, 11, 1, 6, 30); // 6:30 AM
      final next = scheduler.computeNextScheduleTime(8, 0, now);

      expect(next.year, 2026);
      expect(next.month, 11);
      expect(next.day, 1); // Today
      expect(next.hour, 8);
      expect(next.minute, 0);
      expect(next.isAfter(now), isTrue);
    });

    test('computeNextScheduleTime returns 8:00 AM tomorrow if current time is after 8:00 AM', () {
      final now = DateTime(2026, 11, 1, 10, 15); // 10:15 AM
      final next = scheduler.computeNextScheduleTime(8, 0, now);

      expect(next.year, 2026);
      expect(next.month, 11);
      expect(next.day, 2); // Tomorrow
      expect(next.hour, 8);
      expect(next.minute, 0);
      expect(next.isAfter(now), isTrue);
    });

    test('computeNextScheduleTime accurately computes custom hour and minute', () {
      final now = DateTime(2026, 11, 1, 14, 0); // 2:00 PM
      final next = scheduler.computeNextScheduleTime(18, 45, now); // 6:45 PM

      expect(next.day, 1); // Today
      expect(next.hour, 18);
      expect(next.minute, 45);
    });

    test('computeNextScheduleTime rolls over into next month if at end of month', () {
      final now = DateTime(2026, 10, 31, 23, 0); // Oct 31, 11:00 PM
      final next = scheduler.computeNextScheduleTime(8, 0, now);

      expect(next.year, 2026);
      expect(next.month, 11); // November
      expect(next.day, 1);
      expect(next.hour, 8);
      expect(next.minute, 0);
    });
  });
}
