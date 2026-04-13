class SyncStatusSection {
  SyncStatusSection({required this.count, required this.lastUpdatedAt});

  final int count;
  final DateTime? lastUpdatedAt;
}

class SyncStatus {
  SyncStatus({
    required this.categories,
    required this.expenses,
    required this.subscriptions,
  });

  final SyncStatusSection categories;
  final SyncStatusSection expenses;
  final SyncStatusSection subscriptions;

  int get totalCount => categories.count + expenses.count + subscriptions.count;

  DateTime? get latestUpdatedAt {
    DateTime? latest;
    for (final section in [categories, expenses, subscriptions]) {
      final value = section.lastUpdatedAt;
      if (value != null && (latest == null || value.isAfter(latest))) {
        latest = value;
      }
    }
    return latest;
  }
}
