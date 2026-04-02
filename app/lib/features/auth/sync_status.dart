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
}
