String formatTimeRemainingLabel(DateTime target, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = target.difference(reference);

  if (diff.inSeconds.abs() < 60) {
    return 'now';
  }

  if (!diff.isNegative) {
    return 'in ${_formatDurationParts(diff)}';
  }

  return 'overdue by ${_formatDurationParts(reference.difference(target))}';
}

int dayDifferenceFromToday(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final day = DateTime(value.year, value.month, value.day);
  final today = DateTime(reference.year, reference.month, reference.day);
  return day.difference(today).inDays;
}

String formatDueStatusLabel(DateTime dueDate, {DateTime? now}) {
  final days = dayDifferenceFromToday(dueDate, now: now);
  if (days < 0) {
    return 'Overdue by ${-days}d';
  }
  if (days == 0) {
    return 'Due today';
  }
  if (days == 1) {
    return 'Due tomorrow';
  }
  return 'Due in ${days}d';
}

String formatTrialStatusLabel(
  DateTime? trialEnds, {
  DateTime? now,
  String noEndLabel = 'Trial',
}) {
  if (trialEnds == null) {
    return noEndLabel;
  }

  final days = dayDifferenceFromToday(trialEnds, now: now);
  if (days < 0) {
    return 'Trial expired ${-days}d ago';
  }
  if (days == 0) {
    return 'Trial ends today';
  }
  if (days == 1) {
    return 'Trial ends tomorrow';
  }
  return 'Trial ends in ${days}d';
}

String _formatDurationParts(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);

  final parts = <String>[];
  if (days > 0) {
    parts.add('${days}d');
  }
  if (hours > 0 || days > 0) {
    parts.add('${hours}h');
  }
  parts.add('${minutes}m');
  return parts.join(' ');
}
