part of '../database.dart';

@DriftAccessor(tables: [TrashItems])
class TrashDao extends DatabaseAccessor<AppDatabase> with _$TrashDaoMixin {
  TrashDao(super.attachedDatabase);

  Stream<List<TrashItemRow>> watchAll() =>
      (select(trashItems)..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
          .watch();

  Stream<int> watchCount() {
    final count = trashItems.id.count();
    final query = selectOnly(trashItems)..addColumns([count]);
    return query.watch().map((rows) => rows.first.read(count) ?? 0);
  }

  Future<String> insertPayload({
    required String kind,
    required String payload,
    DateTime? deletedAt,
  }) async {
    final row = TrashItemsCompanion.insert(
      id: newUuid(),
      kind: kind,
      payload: payload,
      deletedAt: deletedAt ?? DateTime.now(),
    );
    await into(trashItems).insert(row);
    return row.id.value;
  }

  Future<void> deleteForever(String trashId) =>
      (delete(trashItems)..where((t) => t.id.equals(trashId))).go();

  Future<void> emptyAll() => delete(trashItems).go();

  /// Re-inserts the snapshot and removes the trash row. Returns the kind.
  Future<String> restore(String trashId) async {
    late String kind;
    await attachedDatabase.transaction(() async {
      final item =
          await (select(trashItems)..where((t) => t.id.equals(trashId)))
              .getSingle();
      kind = item.kind;
      final json = jsonDecode(item.payload) as Map<String, dynamic>;
      switch (kind) {
        case 'list':
          await attachedDatabase.taskListDao
              .restoreRow(json['list'] as Map<String, dynamic>);
          for (final t in (json['tasks'] as List? ?? const [])) {
            await attachedDatabase.todoDao.restoreRow(t as Map<String, dynamic>);
          }
        case 'note':
          await attachedDatabase.noteDao.restoreRow(json);
        case 'task':
          final listId = json['listId'] as String;
          final list = await (attachedDatabase.select(
                attachedDatabase.taskLists,
              )..where((t) => t.id.equals(listId)))
              .getSingleOrNull();
          if (list == null) {
            await attachedDatabase.taskListDao.restoreRow({
              'id': newUuid(),
              'title': 'Restored tasks',
              'color': null,
              'createdAt': DateTime.now().toIso8601String(),
            });
            final holder = await (attachedDatabase.select(
                  attachedDatabase.taskLists,
                )..where((t) => t.title.equals('Restored tasks'))
                ..orderBy([(t) => OrderingTerm.desc(t.position)])
                ..limit(1))
                .getSingle();
            await attachedDatabase.todoDao.restoreRow(json, listId: holder.id);
          } else {
            await attachedDatabase.todoDao.restoreRow(json);
          }
        default:
          throw StateError('unknown trash kind: $kind');
      }
      await (delete(trashItems)..where((t) => t.id.equals(trashId))).go();
    });
    return kind;
  }

  /// Deletes items older than [kTrashRetentionDays]; returns count removed.
  Future<int> purgeExpired({DateTime? now}) {
    final cutoff =
        (now ?? DateTime.now()).subtract(
          const Duration(days: kTrashRetentionDays),
        );
    return (delete(trashItems)..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
