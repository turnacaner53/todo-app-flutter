import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('watchCount follows inserts', () async {
    expect(await db.trashDao.watchCount().first, 0);
    final listId = await db.taskListDao.create('A');
    await db.taskListDao.moveToTrash(listId);
    expect(await db.trashDao.watchCount().first, 1);
  });

  test('restore list: list + tasks come back at end', () async {
    await db.taskListDao.create('keep');
    final listId = await db.taskListDao.create('A');
    await db.todoDao.add(listId, 't1');
    final trashId = await db.taskListDao.moveToTrash(listId);

    final kind = await db.trashDao.restore(trashId);
    expect(kind, 'list');
    final lists = await db.taskListDao.watchAll().first;
    expect(lists.map((l) => l.title), ['keep', 'A']);
    final restored = lists.firstWhere((l) => l.title == 'A');
    final tasks = await db.todoDao.watchForList(restored.id).first;
    expect(tasks.map((t) => t.title), ['t1']);
  });

  test('restore task whose list is gone creates "Restored tasks"', () async {
    final listId = await db.taskListDao.create('A');
    final trashId = await db.trashDao.insertPayload(
      kind: 'task',
      payload: '{"id":"t-1","listId":"$listId","title":"orphan",'
          '"completed":false,"completedAt":null,"position":0,'
          '"createdAt":"2026-09-01T00:00:00.000"}',
    );
    await db.taskListDao.moveToTrash(listId);

    final kind = await db.trashDao.restore(trashId);
    expect(kind, 'task');
    final lists = await db.taskListDao.watchAll().first;
    final holder = lists.firstWhere((l) => l.title == 'Restored tasks');
    final tasks = await db.todoDao.watchForList(holder.id).first;
    expect(tasks.single.title, 'orphan');
  });

  test('purgeExpired removes >30d only', () async {
    final now = DateTime(2026, 9);
    await db.trashDao.insertPayload(
      kind: 'note',
      payload: '{}',
      deletedAt: now.subtract(const Duration(days: 31)),
    );
    await db.trashDao.insertPayload(
      kind: 'note',
      payload: '{}',
      deletedAt: now.subtract(const Duration(days: 2)),
    );
    expect(await db.trashDao.purgeExpired(), 1);
    expect(await db.select(db.trashItems).get(), hasLength(1));
  });

  test('deleteForever + emptyAll', () async {
    final id = await db.taskListDao.create('A');
    final trashId = await db.taskListDao.moveToTrash(id);
    await db.trashDao.deleteForever(trashId);
    expect(await db.select(db.trashItems).get(), isEmpty);

    await db.taskListDao.moveToTrash(await db.taskListDao.create('B'));
    await db.trashDao.emptyAll();
    expect(await db.select(db.trashItems).get(), isEmpty);
  });
}
