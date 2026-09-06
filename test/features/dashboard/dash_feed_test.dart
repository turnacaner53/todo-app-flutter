import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/features/dashboard/providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // Abonelikleri canlı tut ki StreamProvider'lar drift akışlarından beslenip
    // dashFeedProvider'a değer aksın.
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    )
      ..listen(taskListsStreamProvider, (_, _) {})
      ..listen(notesStreamProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Olay kuyruğunu boşaltıp güncel birleşik feed'i döndürür.
  Future<List<DashItem>> feed() async {
    await pumpEventQueue();
    return container.read(dashFeedProvider);
  }

  test('dashFeed merges lists and notes by position', () async {
    final l1 = await db.taskListDao.create('L1'); // position 0
    final n1 = await db.noteDao.create(); // position 0
    final n2 = await db.noteDao.create(); // position 1
    await db.taskListDao.setPosition(l1, 5); // L1 son sıraya düşer

    final items = await feed();
    expect(items.map((i) => i.isList).toList(), [false, false, true]);
    expect(items.map((i) => i.id).toList(), [n1, n2, l1]);
  });

  test('createList/createNote then reorder writes positions', () async {
    final actions = container.read(dashboardActionsProvider);
    final id = await actions.createList();
    final id2 = await actions.createList();
    final noteId = await actions.createNote();

    var items = await feed();
    // not'un position'ı önceki not olmadığı için 0; listeler 0,1 →
    // eşitlik createdAt ile bozulur: L1, L2, note.
    expect(items.map((i) => i.id).toSet(), {id, id2, noteId});

    items = [items.firstWhere((i) => i.id == noteId), ...items
        .where((i) => i.id != noteId)];
    await actions.reorder(items);
    final after = await feed();
    expect(after.map((i) => i.id).toList(), [noteId, id, id2]);
  });

  test('moveToTrash routes by kind', () async {
    final actions = container.read(dashboardActionsProvider);
    final listId = await actions.createList();
    final noteId = await actions.createNote();

    final listRow = await (db.select(db.taskLists)
          ..where((t) => t.id.equals(listId)))
        .getSingle();
    final noteRow = await (db.select(db.notes)
          ..where((t) => t.id.equals(noteId)))
        .getSingle();

    await actions.moveToTrash(DashItem.fromList(listRow));
    await actions.moveToTrash(DashItem.fromNote(noteRow));

    expect(await db.trashDao.watchAll().first, hasLength(2));
  });
}
