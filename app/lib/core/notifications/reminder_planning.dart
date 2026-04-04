class ReminderPlan {
  const ReminderPlan({required this.bucketLabel, required this.trigger});

  final String bucketLabel;
  final DateTime trigger;
}

class ReminderPlanning {
  const ReminderPlanning._();

  static const supportedBuckets = ['48h', '24h', 'due'];
  static const _bucketOrder = {'48h': 0, '24h': 1, 'due': 2};

  static ReminderPlan? nextReminderPlan(DateTime dueDate, DateTime now) {
    if (!dueDate.isAfter(now)) {
      return null;
    }

    final trigger48h = dueDate.subtract(const Duration(hours: 48));
    if (trigger48h.isAfter(now)) {
      return ReminderPlan(bucketLabel: '48h', trigger: trigger48h);
    }

    final trigger24h = dueDate.subtract(const Duration(hours: 24));
    if (trigger24h.isAfter(now)) {
      return ReminderPlan(bucketLabel: '24h', trigger: trigger24h);
    }

    return ReminderPlan(bucketLabel: 'due', trigger: dueDate);
  }

  static DateTime? triggerForBucket(DateTime dueDate, String bucketLabel) {
    final bucket = bucketLabel.toLowerCase();
    if (bucket == 'due') {
      return dueDate;
    }
    if (bucket == '48h') {
      return dueDate.subtract(const Duration(hours: 48));
    }
    if (bucket == '24h') {
      return dueDate.subtract(const Duration(hours: 24));
    }
    return null;
  }

  static DateTime nextMonthlyOccurrence(DateTime seed, DateTime now) {
    var cursor = seed;
    while (!cursor.isAfter(now)) {
      cursor = addMonthsKeepingTime(cursor, 1);
    }
    return cursor;
  }

  static DateTime addMonthsKeepingTime(DateTime value, int monthsToAdd) {
    final totalMonths = value.month + monthsToAdd;
    final year = value.year + ((totalMonths - 1) ~/ 12);
    final month = ((totalMonths - 1) % 12) + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = value.day <= maxDay ? value.day : maxDay;

    return DateTime(
      year,
      month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  static bool shouldKeepExistingBucket({
    required String existingBucket,
    required String plannedBucket,
  }) {
    final existing = _bucketOrder[existingBucket.toLowerCase()];
    final planned = _bucketOrder[plannedBucket.toLowerCase()];
    if (existing == null || planned == null) {
      return false;
    }

    // Keep earlier/farther reminders if already pending, so we don't
    // downgrade 48h -> 24h before the original reminder is delivered.
    return existing < planned;
  }
}
