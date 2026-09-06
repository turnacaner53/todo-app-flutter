import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

void main() {
  test('opens in-memory, tables empty, foreign keys enforced', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.select(db.taskLists).get(), isEmpty);
    expect(await db.select(db.todos).get(), isEmpty);
    expect(await db.select(db.notes).get(), isEmpty);
    expect(await db.select(db.trashItems).get(), isEmpty);

    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data['foreign_keys'], 1);
  });
}
