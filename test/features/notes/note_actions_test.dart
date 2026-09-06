import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/features/notes/providers.dart';

void main() {
  test('createNote → save → moveToTrash', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final actions = container.read(noteActionsProvider);

    final id = await actions.createNote();
    var row = await db.noteDao.watchById(id).first;
    expect(row!.title, '');

    await actions.save(
      noteId: id,
      title: 'Groceries',
      content: '[{"insert":"milk"}]',
    );
    row = await db.noteDao.watchById(id).first;
    expect(row!.title, 'Groceries');
    expect(row.content, '[{"insert":"milk"}]');

    final trashId = await actions.moveNoteToTrash(id);
    expect(await db.noteDao.watchById(id).first, isNull);
    final item =
        await (db.select(db.trashItems)..where((t) => t.id.equals(trashId)))
            .getSingle();
    expect(item.kind, 'note');
    expect(item.payload, contains('Groceries'));
  });
}
