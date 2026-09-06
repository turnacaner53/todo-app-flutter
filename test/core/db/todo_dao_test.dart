import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

Future<String> seedList(AppDatabase db) => db.taskListDao.create('L');

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('add appends, setCompleted stamps/clears completedAt', () async {
    final listId = await seedList(db);
    final t = await db.todoDao.add(listId, 'task');
    var row =
        await (db.select(db.todos)..where((x) => x.id.equals(t))).getSingle();
    expect(row.completed, isFalse);
    expect(row.completedAt, isNull);

    await db.todoDao.setCompleted(t, completed: true);
    row =
        await (db.select(db.todos)..where((x) => x.id.equals(t))).getSingle();
    expect(row.completed, isTrue);
    expect(row.completedAt, isNotNull);

    await db.todoDao.setCompleted(t, completed: false);
    row =
        await (db.select(db.todos)..where((x) => x.id.equals(t))).getSingle();
    expect(row.completedAt, isNull);
  });

  test('setPositions applies new order', () async {
    final listId = await seedList(db);
    await db.todoDao.add(listId, 'a');
    await db.todoDao.add(listId, 'b');
    await db.todoDao.add(listId, 'c');

    final rows = await db.todoDao.watchForList(listId).first;
    await db.todoDao.setPositions(
      listId,
      [rows[2].id, rows[0].id, rows[1].id],
    );
    final after = await db.todoDao.watchForList(listId).first;
    expect(after.map((r) => r.title), ['c', 'a', 'b']);
  });

  test('clearCompletedToTrash trashes done tasks, returns trash ids', () async {
    final listId = await seedList(db);
    await db.todoDao.add(listId, 'keep');
    final done = await db.todoDao.add(listId, 'done');
    await db.todoDao.setCompleted(done, completed: true);

    final trashIds = await db.todoDao.clearCompletedToTrash(listId);
    expect(trashIds, hasLength(1));
    expect(
      (await db.todoDao.watchForList(listId).first).map((r) => r.title),
      ['keep'],
    );
    final item = await (db.select(db.trashItems)
          ..where((t) => t.id.equals(trashIds.single)))
        .getSingle();
    expect(item.kind, 'task');
    expect(item.payload, contains('done'));
  });

  test('moveToTrashRow + restoreRow keeps completedAt', () async {
    final listId = await seedList(db);
    final t = await db.todoDao.add(listId, 'x');
    await db.todoDao.setCompleted(t, completed: true);
    final row =
        await (db.select(db.todos)..where((x) => x.id.equals(t))).getSingle();

    await db.todoDao.moveToTrashRow(row);
    expect(await db.select(db.todos).get(), isEmpty);

    await db.todoDao.restoreRow(row.toJson());
    final restored = await db.todoDao.watchForList(listId).first;
    expect(restored.single.completedAt, row.completedAt);
  });

  test('rename task', () async {
    final listId = await seedList(db);
    final t = await db.todoDao.add(listId, 'old');
    await db.todoDao.rename(t, 'new');
    expect((await db.todoDao.watchForList(listId).first).single.title, 'new');
  });
}
