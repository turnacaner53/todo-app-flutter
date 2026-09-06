import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:todo_app_flutterv2/core/db/tables.dart';
import 'package:todo_app_flutterv2/core/utils/id.dart';
import 'package:todo_app_flutterv2/core/utils/time_ago.dart';

part 'database.g.dart';
part 'daos/task_list_dao.dart';
part 'daos/todo_dao.dart';
part 'daos/note_dao.dart';
part 'daos/trash_dao.dart';

@DriftDatabase(
  tables: [TaskLists, Todos, Notes, TrashItems],
  daos: [TaskListDao, TodoDao, NoteDao, TrashDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'todo_app_v2'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX idx_todos_list ON todos (list_id)',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Next append position for a table: COALESCE(MAX(position), -1) + 1.
Future<int> nextPosition(AppDatabase db, String tableName) async {
  final row = await db
      .customSelect('SELECT COALESCE(MAX(position), -1) AS m FROM $tableName')
      .getSingle();
  return (row.data['m'] as int) + 1;
}

/// Parses a drift `toJson()` date value (ISO string or epoch millis).
DateTime parseJsonDate(Object? value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.parse(value);
  throw FormatException('unsupported json date: $value');
}
