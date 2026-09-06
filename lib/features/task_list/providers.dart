import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

enum TaskFilterKind { all, active, done }

List<TodoRow> applyTaskFilter(TaskFilterKind kind, List<TodoRow> rows) =>
    switch (kind) {
      TaskFilterKind.all => rows,
      TaskFilterKind.active => rows.where((t) => !t.completed).toList(),
      TaskFilterKind.done => rows.where((t) => t.completed).toList(),
    };

// Riverpod 3'ün family tipleri public adlandırılmış değil; tip çıkarımı açık
// bırakılıyor. ignore: specify_nonobvious_property_types -- aile sağlayıcı
// türleri paket tarafından dışa aktarılmıyor, elle yazılamaz.
// ignore_for_file: specify_nonobvious_property_types

final taskListProvider = StreamProvider.family<TaskListRow?, String>(
  (ref, listId) => ref.watch(appDatabaseProvider).taskListDao.watchById(listId),
);

final todosOfListProvider = StreamProvider.family<List<TodoRow>, String>(
  (ref, listId) => ref.watch(appDatabaseProvider).todoDao.watchForList(listId),
);

/// Per-list task visibility filter (UI state).
class TaskFilter extends Notifier<TaskFilterKind> {
  TaskFilter(this.listId);

  final String listId;

  @override
  TaskFilterKind build() => TaskFilterKind.all;

  // select() bilinçli bir eylem metodu: state yazması tek prop atamasından
  // fazlası (ileriye dönük: analytics/timeline) — setter'a çevrilmez.
  // ignore: use_setters_to_change_properties
  void select(TaskFilterKind kind) => state = kind;
}

final taskFilterProvider =
    NotifierProvider.family<TaskFilter, TaskFilterKind, String>(TaskFilter.new);

/// Write operations for the list-detail screen.
class TaskListActions {
  TaskListActions(this._db);

  final AppDatabase _db;

  Future<String> addTask({required String listId, required String title}) =>
      _db.todoDao.add(listId, title.trim());

  Future<void> toggle(TodoRow row) =>
      _db.todoDao.setCompleted(row.id, completed: !row.completed);

  Future<void> renameTask({required String taskId, required String title}) =>
      _db.todoDao.rename(taskId, title.trim());

  /// [newIndex] is the insertion index in the list *after* removal.
  Future<void> reorderTasks({
    required String listId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final rows = await _db.todoDao.watchForList(listId).first;
    final ordered = rows.map((r) => r.id).toList();
    ordered.insert(newIndex, ordered.removeAt(oldIndex));
    await _db.todoDao.setPositions(listId, ordered);
  }

  Future<List<String>> clearCompleted(String listId) =>
      _db.todoDao.clearCompletedToTrash(listId);

  Future<void> renameList({required String listId, required String title}) =>
      _db.taskListDao.rename(listId, title.trim());

  Future<void> setListColor(String listId, int? color) =>
      _db.taskListDao.setColor(listId, color);

  Future<String> moveListToTrash(String listId) =>
      _db.taskListDao.moveToTrash(listId);

  Future<String> moveTaskToTrash(TodoRow row) =>
      _db.todoDao.moveToTrashRow(row);
}

final taskListActionsProvider = Provider<TaskListActions>(
  (ref) => TaskListActions(ref.watch(appDatabaseProvider)),
);
