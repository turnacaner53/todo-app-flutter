part of '../database.dart';

@DriftAccessor(tables: [Todos])
class TodoDao extends DatabaseAccessor<AppDatabase> with _$TodoDaoMixin {
  TodoDao(super.attachedDatabase);

  Stream<List<TodoRow>> watchForList(String listId) => (select(todos)
        ..where((t) => t.listId.equals(listId))
        ..orderBy([(t) => OrderingTerm.asc(t.position)]))
      .watch();

  Future<String> add(String listId, String title) async {
    final row = TodosCompanion.insert(
      id: newUuid(),
      listId: listId,
      title: title,
      position: await nextPosition(attachedDatabase, 'todos'),
      createdAt: DateTime.now(),
    );
    await into(todos).insert(row);
    return row.id.value;
  }

  Future<void> rename(String id, String title) =>
      (update(todos)..where((t) => t.id.equals(id)))
          .write(TodosCompanion(title: Value(title)));

  Future<void> setCompleted(String id, {required bool completed}) =>
      (update(todos)..where((t) => t.id.equals(id))).write(TodosCompanion(
        completed: Value(completed),
        completedAt: Value(completed ? DateTime.now() : null),
      ));

  Future<void> setPositions(String listId, List<String> orderedIds) =>
      attachedDatabase.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (update(todos)
                ..where(
                  (t) => t.id.equals(orderedIds[i]) & t.listId.equals(listId),
                ))
              .write(TodosCompanion(position: Value(i)));
        }
      });

  /// Moves all completed tasks to trash; returns trash ids (for undo).
  Future<List<String>> clearCompletedToTrash(String listId) async {
    final done = await (select(todos)
          ..where((t) => t.listId.equals(listId) & t.completed.equals(true)))
        .get();
    return [for (final t in done) await moveToTrashRow(t)];
  }

  Future<String> moveToTrashRow(TodoRow row) async {
    late String trashId;
    await attachedDatabase.transaction(() async {
      trashId = await attachedDatabase.trashDao.insertPayload(
        kind: 'task',
        payload: jsonEncode(row.toJson()),
      );
      await (delete(todos)..where((t) => t.id.equals(row.id))).go();
    });
    return trashId;
  }

  Future<void> restoreRow(Map<String, dynamic> json, {String? listId}) =>
      into(todos).insert(TodosCompanion.insert(
        id: json['id'] as String,
        listId: listId ?? json['listId'] as String,
        title: json['title'] as String,
        completed: Value(json['completed'] as bool? ?? false),
        completedAt: Value(
          json['completedAt'] == null ? null : parseJsonDate(json['completedAt']),
        ),
        position: json['position'] as int? ?? 0,
        createdAt: parseJsonDate(json['createdAt']),
      ));
}
