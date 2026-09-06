const kTrashRetentionDays = 30;

/// Whole days left in trash before purge; clamped to 0.
int trashDaysLeft(DateTime deletedAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(deletedAt).inDays;
  return (kTrashRetentionDays - elapsed).clamp(0, kTrashRetentionDays);
}
