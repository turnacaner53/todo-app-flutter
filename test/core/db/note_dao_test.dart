import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('create → save updates content + updatedAt', () async {
    final id = await db.noteDao.create();
    var row = await db.noteDao.watchById(id).first;
    expect(row!.title, '');
    expect(row.content, '[]');

    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 20));
    await db.noteDao.save(id, title: 'Hello', content: '[{"insert":"Hi"}]');
    row = await db.noteDao.watchById(id).first;
    expect(row!.title, 'Hello');
    expect(row.content, '[{"insert":"Hi"}]');
    expect(row.updatedAt.microsecondsSinceEpoch,
        greaterThan(row.createdAt.microsecondsSinceEpoch));
  });

  test('setColor + moveToTrash → payload kind note', () async {
    final id = await db.noteDao.create();
    await db.noteDao.setColor(id, 0xFF22C55E);
    final trashId = await db.noteDao.moveToTrash(id);
    expect(await db.noteDao.watchById(id).first, isNull);
    final item =
        await (db.select(db.trashItems)..where((t) => t.id.equals(trashId)))
            .getSingle();
    expect(item.kind, 'note');
    expect(
      (jsonDecode(item.payload) as Map<String, dynamic>)['color'],
      0xFF22C55E,
    );
  });
}
