import 'package:flutter_test/flutter_test.dart';
import 'package:vaultspend/core/notifications/reminder_planning.dart';

void main() {
  group('ReminderPlanning.nextReminderPlan', () {
    test('returns 48h bucket when due date is more than 48h away', () {
      final now = DateTime(2026, 4, 1, 9, 0);
      final dueDate = DateTime(2026, 4, 5, 9, 0);

      final plan = ReminderPlanning.nextReminderPlan(dueDate, now);

      expect(plan, isNotNull);
      expect(plan!.bucketLabel, '48h');
      expect(plan.trigger, DateTime(2026, 4, 3, 9, 0));
    });

    test('returns 24h bucket when due date is within 48h but over 24h', () {
      final now = DateTime(2026, 4, 1, 9, 0);
      final dueDate = DateTime(2026, 4, 2, 12, 0);

      final plan = ReminderPlanning.nextReminderPlan(dueDate, now);

      expect(plan, isNotNull);
      expect(plan!.bucketLabel, '24h');
      expect(plan.trigger, DateTime(2026, 4, 1, 12, 0));
    });

    test('returns due bucket when due date is within 24h', () {
      final now = DateTime(2026, 4, 1, 9, 0);
      final dueDate = DateTime(2026, 4, 1, 18, 0);

      final plan = ReminderPlanning.nextReminderPlan(dueDate, now);

      expect(plan, isNotNull);
      expect(plan!.bucketLabel, 'due');
      expect(plan.trigger, dueDate);
    });

    test('returns null when due date is now or in the past', () {
      final now = DateTime(2026, 4, 1, 9, 0);

      final atNow = ReminderPlanning.nextReminderPlan(now, now);
      final inPast = ReminderPlanning.nextReminderPlan(
        DateTime(2026, 4, 1, 8, 59),
        now,
      );

      expect(atNow, isNull);
      expect(inPast, isNull);
    });
  });

  group('ReminderPlanning.nextMonthlyOccurrence', () {
    test('moves forward month-by-month while keeping time of day', () {
      final seed = DateTime(2026, 1, 15, 14, 30, 45);
      final now = DateTime(2026, 4, 16, 9, 0);

      final next = ReminderPlanning.nextMonthlyOccurrence(seed, now);

      expect(next, DateTime(2026, 5, 15, 14, 30, 45));
    });

    test('caps day at end of month when needed (Jan 31 -> Feb 28)', () {
      final value = DateTime(2026, 1, 31, 10, 0);

      final next = ReminderPlanning.addMonthsKeepingTime(value, 1);

      expect(next, DateTime(2026, 2, 28, 10, 0));
    });

    test('handles leap year transitions correctly', () {
      final value = DateTime(2024, 1, 31, 10, 0);

      final next = ReminderPlanning.addMonthsKeepingTime(value, 1);

      expect(next, DateTime(2024, 2, 29, 10, 0));
    });
  });

  group('ReminderPlanning.shouldKeepExistingBucket', () {
    test('keeps existing 48h when planner advances to 24h', () {
      final keep = ReminderPlanning.shouldKeepExistingBucket(
        existingBucket: '48h',
        plannedBucket: '24h',
      );

      expect(keep, isTrue);
    });

    test('does not keep existing 24h when planner wants 48h', () {
      final keep = ReminderPlanning.shouldKeepExistingBucket(
        existingBucket: '24h',
        plannedBucket: '48h',
      );

      expect(keep, isFalse);
    });

    test('keeps matching bucket behavior neutral', () {
      final keep = ReminderPlanning.shouldKeepExistingBucket(
        existingBucket: 'due',
        plannedBucket: 'due',
      );

      expect(keep, isFalse);
    });
  });

  group('ReminderPlanning.triggerForBucket', () {
    test('returns trigger for 48h/24h/due buckets', () {
      final dueDate = DateTime(2026, 4, 6, 23, 18);

      expect(
        ReminderPlanning.triggerForBucket(dueDate, '48h'),
        DateTime(2026, 4, 4, 23, 18),
      );
      expect(
        ReminderPlanning.triggerForBucket(dueDate, '24h'),
        DateTime(2026, 4, 5, 23, 18),
      );
      expect(
        ReminderPlanning.triggerForBucket(dueDate, 'due'),
        dueDate,
      );
    });

    test('returns null for unsupported bucket', () {
      final dueDate = DateTime(2026, 4, 6, 23, 18);
      final trigger = ReminderPlanning.triggerForBucket(dueDate, '12h');

      expect(trigger, isNull);
    });
  });
}
