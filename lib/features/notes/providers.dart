// ignore_for_file: specify_nonobvious_property_types -- family sağlayıcı
// türü paket tarafından dışa aktarılmıyor.
import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

final noteProvider = StreamProvider.family<NoteRow?, String>(
  (ref, noteId) => ref.watch(appDatabaseProvider).noteDao.watchById(noteId),
);

class NoteActions {
  NoteActions(this._db);

  final AppDatabase _db;

  Future<String> createNote() => _db.noteDao.create();

  Future<void> save({
    required String noteId,
    required String title,
    required String content,
  }) => _db.noteDao.save(noteId, title: title, content: content);

  Future<void> setNoteColor(String noteId, int? color) =>
      _db.noteDao.setColor(noteId, color);

  Future<String> moveNoteToTrash(String noteId) =>
      _db.noteDao.moveToTrash(noteId);
}

final noteActionsProvider = Provider<NoteActions>(
  (ref) => NoteActions(ref.watch(appDatabaseProvider)),
);

/// Parses stored delta JSON; blank document for empty input.
///
/// flutter_quill 11's `Document.fromJson` expects the ops **list**, while we
/// store the full delta map (`{"ops": [...]}`) for forward compatibility.
Document parseNoteDocument(String contentJson) {
  final trimmed = contentJson.trim();
  if (trimmed.isEmpty || trimmed == '[]' || trimmed == '{"ops":[]}') {
    return Document();
  }
  final decoded = jsonDecode(trimmed);
  final ops = decoded is Map ? decoded['ops'] as List : decoded as List;
  return Document.fromJson(ops);
}
