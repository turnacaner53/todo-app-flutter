part of '../database.dart';

@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.attachedDatabase);

  Stream<List<NoteRow>> watchAll() =>
      (select(notes)..orderBy([(t) => OrderingTerm.asc(t.position)])).watch();

  Stream<NoteRow?> watchById(String id) =>
      (select(notes)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<String> create() async {
    final now = DateTime.now();
    final row = NotesCompanion.insert(
      id: newUuid(),
      position: await nextPosition(attachedDatabase, 'notes'),
      createdAt: now,
      updatedAt: now,
    );
    await into(notes).insert(row);
    return row.id.value;
  }

  Future<void> save(
    String id, {
    required String title,
    required String content,
  }) =>
      (update(notes)..where((t) => t.id.equals(id))).write(NotesCompanion(
        title: Value(title),
        content: Value(content),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> setColor(String id, int? color) =>
      (update(notes)..where((t) => t.id.equals(id)))
          .write(NotesCompanion(color: Value(color)));

  Future<void> setPosition(String id, int position) =>
      (update(notes)..where((t) => t.id.equals(id)))
          .write(NotesCompanion(position: Value(position)));

  Future<String> moveToTrash(String id) async {
    late String trashId;
    await attachedDatabase.transaction(() async {
      final note =
          await (select(notes)..where((t) => t.id.equals(id))).getSingle();
      trashId = await attachedDatabase.trashDao.insertPayload(
        kind: 'note',
        payload: jsonEncode(note.toJson()),
      );
      await (delete(notes)..where((t) => t.id.equals(id))).go();
    });
    return trashId;
  }

  Future<void> restoreRow(Map<String, dynamic> json) async =>
      into(notes).insert(NotesCompanion.insert(
        id: json['id'] as String,
        title: Value(json['title'] as String),
        content: Value(json['content'] as String),
        color: Value(json['color'] as int?),
        position: await nextPosition(attachedDatabase, 'notes'),
        createdAt: parseJsonDate(json['createdAt']),
        updatedAt: parseJsonDate(json['updatedAt']),
      ));
}
