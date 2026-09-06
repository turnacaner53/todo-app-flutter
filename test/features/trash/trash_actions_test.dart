import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/features/trash/providers.dart';

void main() {
  test('restore/deleteForever/emptyAll via TrashActions', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final actions = container.read(trashActionsProvider);

    final listId = await db.taskListDao.create('A');
    final trashId = await db.taskListDao.moveToTrash(listId);

    expect(await actions.restore(trashId), 'list');
    expect(await db.taskListDao.watchAll().first, hasLength(1));

    final trashId2 = await db.taskListDao.moveToTrash(listId);
    await actions.deleteForever(trashId2);
    expect(await db.select(db.trashItems).get(), isEmpty);

    final idB = await db.taskListDao.create('B');
    await db.taskListDao.moveToTrash(idB);
    expect(await db.trashDao.watchAll().first, hasLength(1));
    await actions.emptyAll();
    expect(await db.trashDao.watchAll().first, isEmpty);
  });

  test('trashItemTitle extracts title from payload', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.taskListDao.create('Shopping');
    final trashId = await db.taskListDao.moveToTrash(id);
    final row = await (db.select(db.trashItems)
          ..where((t) => t.id.equals(trashId)))
        .getSingle();
    expect(trashItemTitle(row), 'Shopping');
    expect(trashItemLabel(row), 'Task list');
  });
}
