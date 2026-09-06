part of '../database.dart';

@DriftAccessor(tables: [TaskLists, Todos])
class TaskListDao extends DatabaseAccessor<AppDatabase>
    with _$TaskListDaoMixin {
  TaskListDao(super.attachedDatabase);

  Stream<List<TaskListRow>> watchAll() =>
      (select(taskLists)..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  Stream<TaskListRow?> watchById(String id) =>
      (select(taskLists)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<String> create(String title) async {
    final row = TaskListsCompanion.insert(
      id: newUuid(),
      title: title,
      position: await nextPosition(attachedDatabase, 'task_lists'),
      createdAt: DateTime.now(),
    );
    await into(taskLists).insert(row);
    return row.id.value;
  }

  Future<void> rename(String id, String title) =>
      (update(taskLists)..where((t) => t.id.equals(id)))
          .write(TaskListsCompanion(title: Value(title)));

  Future<void> setColor(String id, int? color) =>
      (update(taskLists)..where((t) => t.id.equals(id)))
          .write(TaskListsCompanion(color: Value(color)));

  Future<void> setPosition(String id, int position) =>
      (update(taskLists)..where((t) => t.id.equals(id)))
          .write(TaskListsCompanion(position: Value(position)));

  /// Snapshots list + its todos into one trash row, then deletes (cascades).
  Future<String> moveToTrash(String id) async {
    late String trashId;
    await attachedDatabase.transaction(() async {
      final list =
          await (select(taskLists)..where((t) => t.id.equals(id))).getSingle();
      final tasks =
          await (select(todos)..where((t) => t.listId.equals(id))).get();
      trashId = await attachedDatabase.trashDao.insertPayload(
        kind: 'list',
        payload: jsonEncode({
          'list': list.toJson(),
          'tasks': [for (final t in tasks) t.toJson()],
        }),
      );
      await (delete(taskLists)..where((t) => t.id.equals(id))).go();
    });
    return trashId;
  }

  Future<void> restoreRow(Map<String, dynamic> json) async =>
      into(taskLists).insert(TaskListsCompanion.insert(
        id: json['id'] as String,
        title: json['title'] as String,
        color: Value(json['color'] as int?),
        position: await nextPosition(attachedDatabase, 'task_lists'),
        createdAt: parseJsonDate(json['createdAt']),
      ));
}
