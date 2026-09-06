import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/features/task_list/providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TaskListActions actions() => container.read(taskListActionsProvider);

  test('addTask then toggle', () async {
    final listId = await db.taskListDao.create('L');
    final taskId = await actions().addTask(listId: listId, title: 't');
    final row =
        await (db.select(db.todos)..where((t) => t.id.equals(taskId)))
            .getSingle();
    await actions().toggle(row);
    final updated =
        await (db.select(db.todos)..where((t) => t.id.equals(taskId)))
            .getSingle();
    expect(updated.completed, isTrue);
  });

  test('reorderTasks 2 → 0 moves item to front', () async {
    final listId = await db.taskListDao.create('L');
    await db.todoDao.add(listId, 'a');
    await db.todoDao.add(listId, 'b');
    await db.todoDao.add(listId, 'c');
    await actions().reorderTasks(listId: listId, oldIndex: 2, newIndex: 0);
    final rows = await db.todoDao.watchForList(listId).first;
    expect(rows.map((r) => r.title), ['c', 'a', 'b']);
  });

  test('reorderTasks 0 → 2 moves item to end', () async {
    final listId = await db.taskListDao.create('L');
    await db.todoDao.add(listId, 'a');
    await db.todoDao.add(listId, 'b');
    await db.todoDao.add(listId, 'c');
    await actions().reorderTasks(listId: listId, oldIndex: 0, newIndex: 2);
    final rows = await db.todoDao.watchForList(listId).first;
    expect(rows.map((r) => r.title), ['b', 'c', 'a']);
  });

  test('moveTaskToTrash removes row, undo restores it', () async {
    final listId = await db.taskListDao.create('L');
    final taskId = await actions().addTask(listId: listId, title: 'gone');
    final row =
        await (db.select(db.todos)..where((t) => t.id.equals(taskId)))
            .getSingle();

    final trashId = await actions().moveTaskToTrash(row);
    expect(await db.todoDao.watchForList(listId).first, isEmpty);

    await db.trashDao.restore(trashId);
    final restored = await db.todoDao.watchForList(listId).first;
    expect(restored.single.id, taskId);
  });

  test('applyTaskFilter', () {
    TodoRow t(String id, {required bool done}) => TodoRow(
      id: id,
      listId: 'l',
      title: id,
      completed: done,
      position: 0,
      createdAt: DateTime(2026),
    );
    final rows = [t('a', done: false), t('b', done: true), t('c', done: false)];
    expect(applyTaskFilter(TaskFilterKind.all, rows).length, 3);
    expect(applyTaskFilter(TaskFilterKind.active, rows).map((r) => r.id),
        ['a', 'c']);
    expect(applyTaskFilter(TaskFilterKind.done, rows).map((r) => r.id), ['b']);
  });
}
