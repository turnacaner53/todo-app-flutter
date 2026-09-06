import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

class DashItem {
  DashItem.fromList(TaskListRow row)
    : id = row.id,
      title = row.title,
      color = row.color,
      position = row.position,
      sortAt = row.createdAt,
      isList = true,
      listRow = row,
      noteRow = null;

  DashItem.fromNote(NoteRow row)
    : id = row.id,
      title = row.title,
      color = row.color,
      position = row.position,
      sortAt = row.updatedAt,
      isList = false,
      listRow = null,
      noteRow = row;

  final String id;
  final String title;
  final int? color;
  final int position;
  final DateTime sortAt;
  final bool isList;
  final TaskListRow? listRow;
  final NoteRow? noteRow;
}

final taskListsStreamProvider = StreamProvider<List<TaskListRow>>(
  (ref) => ref.watch(appDatabaseProvider).taskListDao.watchAll(),
);

final notesStreamProvider = StreamProvider<List<NoteRow>>(
  (ref) => ref.watch(appDatabaseProvider).noteDao.watchAll(),
);

final trashCountProvider = StreamProvider<int>(
  (ref) => ref.watch(appDatabaseProvider).trashDao.watchCount(),
);

/// Merged, ordered dashboard feed of task lists and notes.
List<DashItem> dashFeed(Ref ref) {
  final lists = ref.watch(taskListsStreamProvider).value ??
      const <TaskListRow>[];
  final notes = ref.watch(notesStreamProvider).value ?? const <NoteRow>[];
  return [
    for (final l in lists) DashItem.fromList(l),
    for (final n in notes) DashItem.fromNote(n),
  ]..sort((a, b) => a.position != b.position
      ? a.position.compareTo(b.position)
      : a.sortAt.compareTo(b.sortAt));
}

final dashFeedProvider = Provider<List<DashItem>>(dashFeed);

class DashboardActions {
  DashboardActions(this._db);

  final AppDatabase _db;

  Future<String> createList() => _db.taskListDao.create('New list');

  Future<String> createNote() => _db.noteDao.create();

  /// Persists merged card order: writes index as position per table.
  Future<void> reorder(List<DashItem> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final item = ordered[i];
      if (item.isList) {
        await _db.taskListDao.setPosition(item.id, i);
      } else {
        await _db.noteDao.setPosition(item.id, i);
      }
    }
  }

  Future<String> moveToTrash(DashItem item) => item.isList
      ? _db.taskListDao.moveToTrash(item.id)
      : _db.noteDao.moveToTrash(item.id);
}

final dashboardActionsProvider = Provider<DashboardActions>(
  (ref) => DashboardActions(ref.watch(appDatabaseProvider)),
);
