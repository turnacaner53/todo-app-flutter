import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('create appends by position, watchAll is ordered', () async {
    await db.taskListDao.create('A');
    await db.taskListDao.create('B');
    final rows = await db.taskListDao.watchAll().first;
    expect(rows.map((r) => r.title), ['A', 'B']);
    expect(rows.map((r) => r.position), [0, 1]);
  });

  test('rename + setColor + setPosition', () async {
    final id = await db.taskListDao.create('A');
    await db.taskListDao.rename(id, 'Renamed');
    await db.taskListDao.setColor(id, 0xFFEF4444);
    await db.taskListDao.setPosition(id, 5);
    final row = (await db.taskListDao.watchById(id).first)!;
    expect(row.title, 'Renamed');
    expect(row.color, 0xFFEF4444);
    expect(row.position, 5);
  });

  test('moveToTrash snapshots list+tasks, delete cascades', () async {
    final listId = await db.taskListDao.create('A');
    await db.todoDao.add(listId, 't1');
    await db.todoDao.add(listId, 't2');

    final trashId = await db.taskListDao.moveToTrash(listId);

    expect(await db.taskListDao.watchById(listId).first, isNull);
    expect(await db.todoDao.watchForList(listId).first, isEmpty);
    final item =
        await (db.select(db.trashItems)..where((t) => t.id.equals(trashId)))
            .getSingle();
    expect(item.kind, 'list');
    expect(item.payload, contains('"list"'));
    expect(item.payload, contains('t1'));
    expect(item.payload, contains('t2'));
  });

  test('restoreRow re-inserts at end position', () async {
    final id = await db.taskListDao.create('A');
    await db.taskListDao.create('B');
    final row =
        await (db.select(db.taskLists)..where((t) => t.id.equals(id)))
            .getSingle();
    await (db.delete(db.taskLists)..where((t) => t.id.equals(id))).go();
    await db.taskListDao.restoreRow(row.toJson());
    final rows = await db.taskListDao.watchAll().first;
    expect(rows.length, 2);
    expect(rows.last.title, 'A');
    expect(rows.last.position, 2);
  });
}
