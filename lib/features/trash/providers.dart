import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

final trashFeedProvider = StreamProvider<List<TrashItemRow>>(
  (ref) => ref.watch(appDatabaseProvider).trashDao.watchAll(),
);

class TrashActions {
  TrashActions(this._db);

  final AppDatabase _db;

  Future<String> restore(String trashId) => _db.trashDao.restore(trashId);

  Future<void> deleteForever(String trashId) =>
      _db.trashDao.deleteForever(trashId);

  Future<void> emptyAll() => _db.trashDao.emptyAll();

  Future<int> purgeExpired() => _db.trashDao.purgeExpired();
}

final trashActionsProvider = Provider<TrashActions>(
  (ref) => TrashActions(ref.watch(appDatabaseProvider)),
);

/// Human label for a trash row.
String trashItemLabel(TrashItemRow row) {
  return switch (row.kind) {
    'list' => 'Task list',
    'note' => 'Note',
    'task' => 'Task',
    _ => 'Item',
  };
}

/// Best-effort title extraction from the stored payload.
String trashItemTitle(TrashItemRow row) {
  try {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final source = json['list'] is Map<String, dynamic>
        ? json['list'] as Map<String, dynamic>
        : json;
    final title = source['title'];
    if (title is String && title.isNotEmpty) return title;
  } on Object {
    // fall through to generic label
  }
  return trashItemLabel(row);
}
