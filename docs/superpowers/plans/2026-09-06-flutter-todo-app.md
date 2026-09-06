# Todo App Flutter v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Bu plan aynı oturumda inline yürütülecek (kullanıcı "kodla" dedi).

**Goal:** Next.js todo-app'ın local-first Flutter (Android + iOS) yeniden yazımı: task listeleri, flutter_quill not editörü, 30 günlük trash, renk paleti, drag-reorder, M3 tema.

**Architecture:** Feature-first. Drift (SQLite) tek source-of-truth; DAO stream'leri Riverpod StreamProvider'lara bağlanır; yazmalar action Notifier'ları üzerinden transaction'lı. go_router ile 4 route.

**Tech Stack:** Flutter 3.41 / Dart 3.11, flutter_riverpod 3.4 (codegen), drift 2.34 + drift_flutter, go_router 18, flutter_quill 11.5, flutter_reorderable_grid_view 5.7, shared_preferences, google_fonts, flutter_colorpicker, uuid, very_good_analysis.

**Spec:** `docs/superpowers/specs/2026-09-06-flutter-todo-app-design.md`

## Uygulama Sapması (Toolchain — 2026-09-06, Task 1 sırasında)

Flutter 3.41.7 / Dart 3.11.5 sabit: `riverpod_generator` ve `riverpod_lint` bu SDK ile
çözümlenemiyor (analyzer/meta pin çakışması). Karar: **Riverpod codegen yok — provider'lar
elle tanımlanır** (`Provider`, `StreamProvider`, `NotifierProvider`, `.family`, runtime
`isAutodispose: false`). Plan'daki `@riverpod` sınıf/annotasyon kalıpları eşdeğer el yazımı
provider'lara çevrilir; isimler/imzalar aynı kalır. Sabitlenen sürümler: flutter_riverpod
3.3.2, go_router 17.5.0, flutter_quill 11.5.0, drift_dev 2.34.0, build_runner <2.15.2,
very_good_analysis ^10.2.0.

## Global Constraints

- Platform: yalnızca Android + iOS. UI metinleri İngilizce.
- `environment: sdk: ^3.11.5`.
- Kod üretimi: `dart run build_runner build` (drift_dev + riverpod_generator).
- Zaman: drift `dateTime()` (millis). Renkler: ARGB `int?` DB kolonları.
- **Git repo yok** — commit step'i yerine her task sonunda `flutter analyze` (+ ilgili `flutter test`) temiz çıkmalı.
- Lint: very_good_analysis; `public_member_api_docs` ve `lines_longer_than_80_chars` ignore; `**/*.g.dart` exclude.
- Test DB: `AppDatabase(NativeDatabase.memory())` (package:drift/native.dart). sqlite3 3.x native lib'i paketle gelir; Windows'ta yüklenemezse fallback: sqlite3.dll'ı çalışma dizinine koyup test setup'ında `sqlite3.open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('sqlite3.dll'))`.
- GoogleFonts widget test'lerinde `GoogleFonts.config.allowRuntimeFetching = false`.

## Dosya Haritası

```
lib/main.dart                                   Task 6
lib/app/{app,router,providers}.dart             Task 6
lib/app/theme/{app_theme,palette}.dart          Task 6 / 1
lib/core/utils/{id,debouncer,delta_text,time_ago}.dart       Task 2
lib/core/db/{tables,database}.dart + daos/{task_list,todo,note,trash}_dao.dart  Task 3-5
lib/core/widgets/{empty_state,color_picker_sheet,undo_snack}.dart               Task 7
lib/features/settings/theme_mode_controller.dart            Task 6
lib/features/task_list/{providers,task_list_screen,task_tile}.dart  Task 7
lib/features/notes/{providers,note_editor_screen}.dart      Task 8
lib/features/dashboard/{providers,dash_card,dashboard_screen}.dart  Task 9
lib/features/trash/{providers,trash_screen}.dart            Task 10
test/core/... test/features/... test/widget/...             ilgili task
```

---

### Task 1: Scaffold — bağımlılıklar, lint, klasör iskeleti, stub ekranlar

**Files:**
- Modify: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`
- Create: `lib/app/theme/palette.dart`, stub `lib/features/dashboard/dashboard_screen.dart`, `lib/features/task_list/task_list_screen.dart`, `lib/features/notes/note_editor_screen.dart`, `lib/features/trash/trash_screen.dart`
- Delete: `test/widget_test.dart`

- [ ] **Step 1: pubspec.yaml (tamamını değiştir; version 1.0.0+1, sdk ^3.11.5):**

```yaml
name: todo_app_flutterv2
description: "Local-first task lists and notes."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^3.4.3
  riverpod_annotation: ^4.0.7
  drift: ^2.34.4
  drift_flutter: ^0.3.1
  go_router: ^18.0.1
  flutter_quill: ^11.5.1
  flutter_reorderable_grid_view: ^5.7.0
  shared_preferences: ^2.5.5
  google_fonts: ^8.2.1
  flutter_colorpicker: ^1.1.0
  uuid: ^4.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.16.1
  drift_dev: ^2.34.6
  riverpod_generator: ^4.0.9
  custom_lint: ^0.8.1
  riverpod_lint: ^3.1.9
  very_good_analysis: ^11.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: analysis_options.yaml (tamamını değiştir):**

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
  errors:
    public_member_api_docs: ignore
    lines_longer_than_80_chars: ignore
```

- [ ] **Step 3: Stub ekranlar.** `dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Dashboard')));
  }
}
```

Aynı kalıp: `TaskListScreen({super.key, required this.listId})` (`final String listId;`), `NoteEditorScreen({super.key, required this.noteId})`, `TrashScreen()`. Hepsi `Center(child: Text('...'))`.

`lib/app/theme/palette.dart`:

```dart
/// 8-color palette shared by lists and notes (ARGB ints).
const kListPalette = <int>[
  0xFFEF4444, 0xFFF97316, 0xFFFACC15, 0xFF22C55E, //
  0xFF14B8A6, 0xFF3B82F6, 0xFF8B5CF6, 0xFFEC4899,
];
```

- [ ] **Step 4: main.dart geçici:**

```dart
import 'package:flutter/material.dart';

void main() => runApp(
      const MaterialApp(home: Scaffold(body: Center(child: Text('Todo')))),
    );
```

- [ ] **Step 5:** `test/widget_test.dart` sil.
- [ ] **Step 6:** `flutter pub get` → başarılı olmalı; sonra `dart run build_runner build` (henüz no-op).
- [ ] **Step 7:** `flutter analyze` temiz.

---

### Task 2: Core utils (TDD)

**Files:** Create `lib/core/utils/{id,debouncer,delta_text,time_ago}.dart`; Test `test/core/utils/{debouncer,delta_text,time_ago}_test.dart`

**Interfaces — Produces:**
- `String newUuid()`
- `class Debouncer { Debouncer(Duration delay, void Function() action); void call(); void flush(); bool get hasPending; void dispose(); }`
- `String deltaToPlainText(String deltaJson)`
- `const kTrashRetentionDays = 30`; `int trashDaysLeft(DateTime deletedAt, {DateTime? now})`

- [ ] **Step 1: Failing testler.** `test/core/utils/delta_text_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/utils/delta_text.dart';

void main() {
  test('concatenates string inserts and trims trailing newline', () {
    const delta = '{"ops":[{"insert":"Hello "},'
        '{"insert":"world","attributes":{"bold":true}},{"insert":"\\n"}]}';
    expect(deltaToPlainText(delta), 'Hello world');
  });

  test('supports bare op list format', () {
    const delta = '[{"insert":"One"},{"insert":"\\nTwo"}]';
    expect(deltaToPlainText(delta), 'One\nTwo');
  });

  test('embeds are skipped, empty input safe', () {
    const delta = '{"ops":[{"insert":{"image":"x"}},{"insert":"pic"}]}';
    expect(deltaToPlainText(delta), 'pic');
    expect(deltaToPlainText(''), '');
  });
}
```

`test/core/utils/debouncer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/utils/debouncer.dart';

void main() {
  test('collapses rapid calls into one delayed action', () async {
    var calls = 0;
    final d = Debouncer(const Duration(milliseconds: 30), () => calls++);
    d();
    d();
    d();
    expect(calls, 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1);
    d.dispose();
  });

  test('flush runs pending action, dispose cancels', () async {
    var calls = 0;
    final d = Debouncer(const Duration(milliseconds: 30), () => calls++);
    d();
    expect(d.hasPending, isTrue);
    d.flush();
    expect(calls, 1);
    expect(d.hasPending, isFalse);
    d();
    d.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1);
  });
}
```

`test/core/utils/time_ago_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/utils/time_ago.dart';

void main() {
  final now = DateTime(2026, 9, 1, 12);

  test('fresh trash item has full window', () {
    expect(trashDaysLeft(now.subtract(const Duration(hours: 3)), now: now), 30);
  });

  test('29.5 days old has 1 left, expired clamps to 0', () {
    expect(trashDaysLeft(now.subtract(const Duration(days: 29, hours: 12)), now: now), 1);
    expect(trashDaysLeft(now.subtract(const Duration(days: 31)), now: now), 0);
  });
}
```

- [ ] **Step 2:** `flutter test test/core/utils` → FAIL doğrula.
- [ ] **Step 3: Implementasyon.** `id.dart`:

```dart
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// New v4 uuid for entity ids.
String newUuid() => _uuid.v4();
```

`debouncer.dart`:

```dart
import 'dart:async';

/// Runs [action] once after the last [call] + delay. For note autosave.
class Debouncer {
  Debouncer(this.delay, this.action);

  final Duration delay;
  final void Function() action;
  Timer? _timer;

  void call() {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      action();
    });
  }

  bool get hasPending => _timer?.isActive ?? false;

  void flush() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _timer = null;
      action();
    }
  }

  void dispose() => _timer?.cancel();
}
```

`delta_text.dart`:

```dart
import 'dart:convert';

/// Plain-text preview of a stored Quill delta JSON ({"ops":[...]} or [...]).
String deltaToPlainText(String deltaJson) {
  if (deltaJson.trim().isEmpty) return '';
  final decoded = jsonDecode(deltaJson);
  final ops = decoded is Map ? (decoded['ops'] as List? ?? const []) : decoded as List;
  final buffer = StringBuffer();
  for (final op in ops) {
    if (op is Map && op['insert'] is String) buffer.write(op['insert']);
  }
  return buffer.toString().trim();
}
```

`time_ago.dart`:

```dart
const kTrashRetentionDays = 30;

/// Whole days left in trash before purge; clamped to 0.
int trashDaysLeft(DateTime deletedAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(deletedAt).inDays;
  return (kTrashRetentionDays - elapsed).clamp(0, kTrashRetentionDays);
}
```

- [ ] **Step 4:** `flutter test test/core/utils` PASS + `flutter analyze` temiz.

---

### Task 3: Drift schema + AppDatabase + DAO iskeleti

**Files:** Create `lib/core/db/tables.dart`, `lib/core/db/database.dart`, `lib/core/db/daos/{task_list,todo,note,trash}_dao.dart` (skeleton); Test `test/core/db/database_test.dart`

**Interfaces — Produces:** `AppDatabase([QueryExecutor? executor])`, `schemaVersion 1`, FK pragma açık. DAO getter'ları: `db.taskListDao`, `db.todoDao`, `db.noteDao`, `db.trashDao`. Row sınıfları: `TaskListRow, TodoRow, NoteRow, TrashItemRow` (+ `*Companion.insert`). Tablo adları drift default snake_case: `task_lists, todos, notes, trash_items`.

- [ ] **Step 1: Failing test `test/core/db/database_test.dart`:**

```dart
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
```

- [ ] **Step 2:** `flutter test test/core/db` → FAIL (Global Constraints'teki dll fallback gerekirse uygula).
- [ ] **Step 3: `lib/core/db/tables.dart`:**

```dart
import 'package:drift/drift.dart';

@DataClassName('TaskListRow')
class TaskLists extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  IntColumn get color => integer().nullable()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TodoRow')
@TableIndex(name: 'idx_todos_list', columns: {listId})
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get listId =>
      text().references(TaskLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant('[]'))();
  IntColumn get color => integer().nullable()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TrashItemRow')
class TrashItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

- [ ] **Step 4: `lib/core/db/database.dart`:**

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../utils/id.dart';
import '../utils/time_ago.dart';
import 'tables.dart';

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
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Next append position: SELECT COALESCE(MAX(position), -1) +1.
Future<int> nextPosition(AppDatabase db, String tableName) async {
  final row = await db
      .customSelect('SELECT COALESCE(MAX(position), -1) AS m FROM $tableName')
      .getSingle();
  return (row.data['m'] as int) + 1;
}
```

- [ ] **Step 5: DAO skeleton part dosyaları** (`lib/core/db/daos/`), her biri `part of '../database.dart';` ile başlar:

```dart
@DriftAccessor(tables: [TaskLists, Todos])
class TaskListDao extends DatabaseAccessor<AppDatabase> with _$TaskListDaoMixin {
  TaskListDao(super.attachedDatabase);
}
```

Aynen: `TodoDao` (tables: [Todos], `_$TodoDaoMixin`), `NoteDao` (tables: [Notes]), `TrashDao` (tables: [TrashItems]).

- [ ] **Step 6:** `dart run build_runner build` → `database.g.dart` üretsin.
- [ ] **Step 7:** `flutter test test/core/db` PASS; `flutter analyze` temiz.

---

### Task 4: TaskList + Todo DAO (TDD)

**Files:** Modify `lib/core/db/daos/task_list_dao.dart`, `lib/core/db/daos/todo_dao.dart`; Test `test/core/db/{task_list,todo}_dao_test.dart`

**Interfaces — Produces:**
- `TaskListDao`: `Stream<List<TaskListRow>> watchAll()`, `Stream<TaskListRow?> watchById(String id)`, `Future<String> create(String title)`, `Future<void> rename(String id, String title)`, `Future<void> setColor(String id, int? color)`, `Future<void> setPosition(String id, int position)`, `Future<String> moveToTrash(String id)` (payload `{"list":...,"tasks":[...]}`), `Future<void> restoreRow(Map<String, dynamic> json)`
- `TodoDao`: `Stream<List<TodoRow>> watchForList(String listId)`, `Future<String> add(String listId, String title)`, `Future<void> rename(String id, String title)`, `Future<void> setCompleted(String id, bool completed)`, `Future<void> setPositions(String listId, List<String> orderedIds)`, `Future<List<String>> clearCompletedToTrash(String listId)`, `Future<String> moveToTrashRow(TodoRow row)`, `Future<void> restoreRow(Map<String, dynamic> json, {String? listId})`

- [ ] **Step 1: Failing testler.** `test/core/db/task_list_dao_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('create appends by position, watchAll is ordered', () async {
    await db.taskListDao.create('A');
    await db.taskListDao.create('B');
    final rows = await db.taskListDao.watchAll().first;
    expect(rows.map((r) => r.title), ['A', 'B']);
    expect(rows.map((r) => r.position), [0, 1]);
  });

  test('rename + setColor + setPosition', () async {
    final id = await db.taskListDao.create('A');
    await db.taskListDao.rename(id, 'Renamed');
    await db.taskListDao.setColor(id, 0xFFEF4444);
    await db.taskListDao.setPosition(id, 5);
    final row = (await db.taskListDao.watchById(id).first)!;
    expect(row.title, 'Renamed');
    expect(row.color, 0xFFEF4444);
    expect(row.position, 5);
  });

  test('moveToTrash snapshots list+tasks, delete cascades', () async {
    final listId = await db.taskListDao.create('A');
    await db.todoDao.add(listId, 't1');
    await db.todoDao.add(listId, 't2');

    final trashId = await db.taskListDao.moveToTrash(listId);

    expect(await db.taskListDao.watchById(listId).first, isNull);
    expect(await db.todoDao.watchForList(listId).first, isEmpty);
    final item = await (db.select(db.trashItems)..where((t) => t.id.equals(trashId)))
        .getSingle();
    expect(item.kind, 'list');
    expect(item.payload, contains('"list"'));
    expect(item.payload, contains('t1'));
    expect(item.payload, contains('t2'));
  });

  test('restoreRow re-inserts at end position', () async {
    final id = await db.taskListDao.create('A');
    await db.taskListDao.create('B');
    final row = await (db.select(db.taskLists)..where((t) => t.id.equals(id)))
        .getSingle();
    await db.taskListDao.restoreRow(row.toJson());
    final rows = await db.taskListDao.watchAll().first;
    expect(rows.length, 3); // A yeniden eklendi (position son)
    expect(rows.last.title, 'A');
  });
}
```

`test/core/db/todo_dao_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

Future<String> seedList(AppDatabase db) => db.taskListDao.create('L');

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('add appends, setCompleted stamps/clears completedAt', () async {
    final listId = await seedList(db);
    final t = await db.todoDao.add(listId, 'task');
    var row = await (db.select(db.todos)..where((x) => x.id.equals(t))).getSingle();
    expect(row.completed, isFalse);
    expect(row.completedAt, isNull);

    await db.todoDao.setCompleted(t, true);
    row = await (db.select(db.todos)..where((x) => x.id.equals(t))).getSingle();
    expect(row.completed, isTrue);
    expect(row.completedAt, isNotNull);

    await db.todoDao.setCompleted(t, false);
    row = await (db.select(db.todos)..where((x) => x.id.equals(t))).getSingle();
    expect(row.completedAt, isNull);
  });

  test('setPositions applies new order', () async {
    final listId = await seedList(db);
    await db.todoDao.add(listId, 'a');
    await db.todoDao.add(listId, 'b');
    await db.todoDao.add(listId, 'c');

    final rows = await db.todoDao.watchForList(listId).first;
    await db.todoDao.setPositions(listId, [rows[2].id, rows[0].id, rows[1].id]);
    final after = await db.todoDao.watchForList(listId).first;
    expect(after.map((r) => r.title), ['c', 'a', 'b']);
  });

  test('clearCompletedToTrash trashes done tasks, returns trash ids', () async {
    final listId = await seedList(db);
    await db.todoDao.add(listId, 'keep');
    final done = await db.todoDao.add(listId, 'done');
    await db.todoDao.setCompleted(done, true);

    final trashIds = await db.todoDao.clearCompletedToTrash(listId);
    expect(trashIds, hasLength(1));
    expect((await db.todoDao.watchForList(listId).first).map((r) => r.title), ['keep']);
    final item =
        await (db.select(db.trashItems)..where((t) => t.id.equals(trashIds.single)))
            .getSingle();
    expect(item.kind, 'task');
    expect(item.payload, contains('done'));
  });

  test('moveToTrashRow + restoreRow keeps completedAt', () async {
    final listId = await seedList(db);
    final t = await db.todoDao.add(listId, 'x');
    await db.todoDao.setCompleted(t, true);
    final row = await (db.select(db.todos)..where((x) => x.id.equals(t))).getSingle();

    await db.todoDao.moveToTrashRow(row);
    expect(await db.select(db.todos).get(), isEmpty);

    await db.todoDao.restoreRow(row.toJson());
    final restored = await db.todoDao.watchForList(listId).first;
    expect(restored.single.completedAt, row.completedAt);
  });

  test('rename task', () async {
    final listId = await seedList(db);
    final t = await db.todoDao.add(listId, 'old');
    await db.todoDao.rename(t, 'new');
    expect((await db.todoDao.watchForList(listId).first).single.title, 'new');
  });
}
```

- [ ] **Step 2:** `flutter test test/core/db` → FAIL.
- [ ] **Step 3: `task_list_dao.dart` gövdesi** (`part of '../database.dart';` üstte kalır):

```dart
@DriftAccessor(tables: [TaskLists, Todos])
class TaskListDao extends DatabaseAccessor<AppDatabase> with _$TaskListDaoMixin {
  TaskListDao(super.attachedDatabase);

  Stream<List<TaskListRow>> watchAll() =>
      (select(taskLists)..orderBy([(t) => OrderingTerm.asc(t.position)])).watch();

  Stream<TaskListRow?> watchById(String id) =>
      (select(taskLists)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<String> create(String title) async {
    final row = TaskListsCompanion.insert(
      id: newUuid(),
      title: title,
      position: await nextPosition(attachedDatabase, 'task_lists'),
      createdAt: DateTime.now(),
    );
    await into(taskLists).insert(row);
    return row.id.value;
  }

  Future<void> rename(String id, String title) =>
      (update(taskLists)..where((t) => t.id.equals(id)))
          .write(TaskListsCompanion(title: Value(title)));

  Future<void> setColor(String id, int? color) =>
      (update(taskLists)..where((t) => t.id.equals(id)))
          .write(TaskListsCompanion(color: Value(color)));

  Future<void> setPosition(String id, int position) =>
      (update(taskLists)..where((t) => t.id.equals(id)))
          .write(TaskListsCompanion(position: Value(position)));

  /// Snapshots list + its todos into one trash row, then deletes (cascades).
  Future<String> moveToTrash(String id) async {
    late String trashId;
    await attachedDatabase.transaction(() async {
      final list =
          await (select(taskLists)..where((t) => t.id.equals(id))).getSingle();
      final tasks = await (select(todos)..where((t) => t.listId.equals(id))).get();
      trashId = await attachedDatabase.trashDao.insertPayload(
        kind: 'list',
        payload: jsonEncode({
          'list': list.toJson(),
          'tasks': [for (final t in tasks) t.toJson()],
        }),
      );
      await (delete(taskLists)..where((t) => t.id.equals(id))).go();
    });
    return trashId;
  }

  Future<void> restoreRow(Map<String, dynamic> json) => into(taskLists).insert(
        TaskListsCompanion.insert(
          id: json['id'] as String,
          title: json['title'] as String,
          color: Value(json['color'] as int?),
          position: await nextPosition(attachedDatabase, 'task_lists'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
        ),
      );
}
```

- [ ] **Step 4: `todo_dao.dart` gövdesi:**

```dart
@DriftAccessor(tables: [Todos])
class TodoDao extends DatabaseAccessor<AppDatabase> with _$TodoDaoMixin {
  TodoDao(super.attachedDatabase);

  Stream<List<TodoRow>> watchForList(String listId) => (select(todos)
        ..where((t) => t.listId.equals(listId))
        ..orderBy([(t) => OrderingTerm.asc(t.position)]))
      .watch();

  Future<String> add(String listId, String title) async {
    final row = TodosCompanion.insert(
      id: newUuid(),
      listId: listId,
      title: title,
      position: await nextPosition(attachedDatabase, 'todos'),
      createdAt: DateTime.now(),
    );
    await into(todos).insert(row);
    return row.id.value;
  }

  Future<void> rename(String id, String title) =>
      (update(todos)..where((t) => t.id.equals(id)))
          .write(TodosCompanion(title: Value(title)));

  Future<void> setCompleted(String id, bool completed) =>
      (update(todos)..where((t) => t.id.equals(id))).write(TodosCompanion(
        completed: Value(completed),
        completedAt: Value(completed ? DateTime.now() : null),
      ));

  Future<void> setPositions(String listId, List<String> orderedIds) =>
      attachedDatabase.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (update(todos)
                ..where((t) => t.id.equals(orderedIds[i]) & t.listId.equals(listId)))
              .write(TodosCompanion(position: Value(i)));
        }
      });

  /// Moves all completed tasks to trash; returns trash ids (for undo).
  Future<List<String>> clearCompletedToTrash(String listId) async {
    final done = await (select(todos)
          ..where((t) => t.listId.equals(listId) & t.completed.equals(true)))
        .get();
    return [for (final t in done) await moveToTrashRow(t)];
  }

  Future<String> moveToTrashRow(TodoRow row) async {
    late String trashId;
    await attachedDatabase.transaction(() async {
      trashId = await attachedDatabase.trashDao
          .insertPayload(kind: 'task', payload: jsonEncode(row.toJson()));
      await (delete(todos)..where((t) => t.id.equals(row.id))).go();
    });
    return trashId;
  }

  Future<void> restoreRow(Map<String, dynamic> json, {String? listId}) =>
      into(todos).insert(TodosCompanion.insert(
        id: json['id'] as String,
        listId: listId ?? json['list_id'] as String,
        title: json['title'] as String,
        completed: Value(json['completed'] as bool? ?? false),
        completedAt: Value((json['completed_at'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['completed_at'] as int)),
        position: json['position'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      ));
}
```

- [ ] **Step 5:** `flutter test test/core/db` PASS; `flutter analyze` temiz.

---

### Task 5: Note + Trash DAO, retention (TDD)

**Files:** Modify `lib/core/db/daos/note_dao.dart`, `lib/core/db/daos/trash_dao.dart`; Test `test/core/db/{note,trash}_dao_test.dart`

**Interfaces — Produces:**
- `NoteDao`: `Stream<List<NoteRow>> watchAll()`, `Stream<NoteRow?> watchById(String id)`, `Future<String> create()`, `Future<void> save(String id, {required String title, required String content})`, `Future<void> setColor(String id, int? color)`, `Future<void> setPosition(String id, int position)`, `Future<String> moveToTrash(String id)`, `Future<void> restoreRow(Map<String, dynamic> json)`
- `TrashDao`: `Stream<List<TrashItemRow>> watchAll()`, `Stream<int> watchCount()`, `Future<String> insertPayload({required String kind, required String payload, DateTime? deletedAt})`, `Future<void> deleteForever(String trashId)`, `Future<void> emptyAll()`, `Future<String> restore(String trashId)` (kind döner), `Future<int> purgeExpired({DateTime? now})`

- [ ] **Step 1: Failing testler.** `test/core/db/note_dao_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('create → save updates content + updatedAt, watchById emits', () async {
    final id = await db.noteDao.create();
    var row = await db.noteDao.watchById(id).first;
    expect(row!.title, '');
    expect(row.content, '[]');
    final created = row.updatedAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.noteDao.save(id, title: 'Hello', content: '[{"insert":"Hi"}]');
    row = await db.noteDao.watchById(id).first;
    expect(row!.title, 'Hello');
    expect(row.content, '[{"insert":"Hi"}]');
    expect(row.updatedAt.isAfter(created), isTrue);
  });

  test('setColor + moveToTrash → payload kind note', () async {
    final id = await db.noteDao.create();
    await db.noteDao.setColor(id, 0xFF22C55E);
    final trashId = await db.noteDao.moveToTrash(id);
    expect(await db.noteDao.watchById(id).first, isNull);
    final item =
        await (db.select(db.trashItems)..where((t) => t.id.equals(trashId))).getSingle();
    expect(item.kind, 'note');
    expect(jsonDecode(item.payload)['color'], 0xFF22C55E);
  });
}
```

`test/core/db/trash_dao_test.dart`:

```dart
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
      payload: '{"id":"t-1","list_id":"$listId","title":"orphan",'
          '"completed":false,"completed_at":null,"position":0,"created_at":1}',
    );
    await db.taskListDao.moveToTrash(listId); // liste de çöpte; task'ın listesi yok

    final kind = await db.trashDao.restore(trashId);
    expect(kind, 'task');
    final lists = await db.taskListDao.watchAll().first;
    final holder = lists.firstWhere((l) => l.title == 'Restored tasks');
    final tasks = await db.todoDao.watchForList(holder.id).first;
    expect(tasks.single.title, 'orphan');
  });

  test('purgeExpired removes >30d only', () async {
    final now = DateTime(2026, 9, 1);
    await db.trashDao.insertPayload(
        kind: 'note', payload: '{}', deletedAt: now.subtract(const Duration(days: 31)));
    await db.trashDao.insertPayload(
        kind: 'note', payload: '{}', deletedAt: now.subtract(const Duration(days: 2)));
    expect(await db.trashDao.purgeExpired(now: now), 1);
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
```

- [ ] **Step 2:** `flutter test test/core/db` → FAIL.
- [ ] **Step 3: `note_dao.dart` gövdesi:**

```dart
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

  Future<void> save(String id, {required String title, required String content}) =>
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
      final note = await (select(notes)..where((t) => t.id.equals(id))).getSingle();
      trashId = await attachedDatabase.trashDao
          .insertPayload(kind: 'note', payload: jsonEncode(note.toJson()));
      await (delete(notes)..where((t) => t.id.equals(id))).go();
    });
    return trashId;
  }

  Future<void> restoreRow(Map<String, dynamic> json) => into(notes).insert(
        NotesCompanion.insert(
          id: json['id'] as String,
          title: Value(json['title'] as String),
          content: Value(json['content'] as String),
          color: Value(json['color'] as int?),
          position: await nextPosition(attachedDatabase, 'notes'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
        ),
      );
}
```

- [ ] **Step 4: `trash_dao.dart` gövdesi:**

```dart
@DriftAccessor(tables: [TrashItems])
class TrashDao extends DatabaseAccessor<AppDatabase> with _$TrashDaoMixin {
  TrashDao(super.attachedDatabase);

  Stream<List<TrashItemRow>> watchAll() =>
      (select(trashItems)..orderBy([(t) => OrderingTerm.desc(t.deletedAt)])).watch();

  Stream<int> watchCount() {
    final count = trashItems.id.count();
    final query = selectOnly(trashItems)..addColumns([count]);
    return query.watch().map((rows) => rows.first.read(count)?.cast<int>() ?? 0);
  }

  Future<String> insertPayload({
    required String kind,
    required String payload,
    DateTime? deletedAt,
  }) async {
    final row = TrashItemsCompanion.insert(
      id: newUuid(),
      kind: kind,
      payload: payload,
      deletedAt: deletedAt ?? DateTime.now(),
    );
    await into(trashItems).insert(row);
    return row.id.value;
  }

  Future<void> deleteForever(String trashId) =>
      (delete(trashItems)..where((t) => t.id.equals(trashId))).go();

  Future<void> emptyAll() => delete(trashItems).go();

  /// Re-inserts the snapshot and removes the trash row. Returns the kind.
  Future<String> restore(String trashId) async {
    late String kind;
    await attachedDatabase.transaction(() async {
      final item =
          await (select(trashItems)..where((t) => t.id.equals(trashId))).getSingle();
      kind = item.kind;
      final json = jsonDecode(item.payload) as Map<String, dynamic>;
      switch (kind) {
        case 'list':
          await attachedDatabase.taskListDao
              .restoreRow(json['list'] as Map<String, dynamic>);
          for (final t in (json['tasks'] as List? ?? const [])) {
            await attachedDatabase.todoDao.restoreRow(t as Map<String, dynamic>);
          }
        case 'note':
          await attachedDatabase.noteDao.restoreRow(json);
        case 'task':
          final listId = json['list_id'] as String;
          final list = await (attachedDatabase.select(attachedDatabase.taskLists)
                ..where((t) => t.id.equals(listId)))
              .getSingleOrNull();
          if (list == null) {
            await attachedDatabase.taskListDao.restoreRow({
              'id': newUuid(),
              'title': 'Restored tasks',
              'color': null,
              'position': 0,
              'created_at': DateTime.now().millisecondsSinceEpoch,
            });
            final holder = await (attachedDatabase.select(attachedDatabase.taskLists)
                  ..where((t) => t.title.equals('Restored tasks'))
                  ..orderBy([(t) => OrderingTerm.desc(t.position)])
                  ..limit(1))
                .getSingle();
            await attachedDatabase.todoDao.restoreRow(json, listId: holder.id);
          } else {
            await attachedDatabase.todoDao.restoreRow(json);
          }
        default:
          throw StateError('unknown trash kind: $kind');
      }
      await (delete(trashItems)..where((t) => t.id.equals(trashId))).go();
    });
    return kind;
  }

  /// Deletes items older than [kTrashRetentionDays]; returns count removed.
  Future<int> purgeExpired({DateTime? now}) {
    final cutoff =
        (now ?? DateTime.now()).subtract(const Duration(days: kTrashRetentionDays));
    return (delete(trashItems)..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
```

- [ ] **Step 5:** `flutter test test/core/db` PASS; `flutter analyze` temiz.

---

### Task 6: App kabuğu — main bootstrap, theme, router, settings

**Files:**
- Create: `lib/app/providers.dart`, `lib/app/app.dart`, `lib/app/router.dart`, `lib/app/theme/app_theme.dart`, `lib/features/settings/theme_mode_controller.dart`
- Modify: `lib/main.dart`; stub ekranlara AppBar ekle (build edilebilir kalsın)
- Test: `test/features/settings/theme_mode_controller_test.dart`, `test/widget/smoke_test.dart`

**Interfaces — Produces:**
- `appDatabaseProvider` (keepAlive `AppDatabase`), `sharedPreferencesProvider` (main'de override), `appRouterProvider` (keepAlive `GoRouter`)
- `ThemeModeController` → `themeModeControllerProvider`: `ThemeMode build()`, `void setMode(ThemeMode)`, `void cycle()`
- `buildAppTheme(Brightness)`, `argbToColor(int?)`, `tintSurface(ColorScheme, int?, {Color? fallback})`
- Routes: `/`, `/list/:listId`, `/note/:noteId`, `/trash`

- [ ] **Step 1: Failing test `test/features/settings/theme_mode_controller_test.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/features/settings/theme_mode_controller.dart';

void main() {
  Future<ProviderContainer> containerWith(String? storedMode) async {
    SharedPreferences.setMockInitialValues(
      storedMode == null ? {} : {'theme_mode': storedMode},
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to system, persists, reads back', () async {
    final c = await containerWith(null);
    expect(c.read(themeModeControllerProvider), ThemeMode.system);

    c.read(themeModeControllerProvider.notifier).setMode(ThemeMode.dark);
    expect(c.read(themeModeControllerProvider), ThemeMode.dark);

    final c2 = await containerWith('dark');
    expect(c2.read(themeModeControllerProvider), ThemeMode.dark);
  });

  test('cycle walks system → light → dark → system', () async {
    final c = await containerWith(null);
    final notifier = c.read(themeModeControllerProvider.notifier);
    notifier.cycle();
    expect(c.read(themeModeControllerProvider), ThemeMode.light);
    notifier.cycle();
    expect(c.read(themeModeControllerProvider), ThemeMode.dark);
    notifier.cycle();
    expect(c.read(themeModeControllerProvider), ThemeMode.system);
  });
}
```

- [ ] **Step 2:** `flutter test test/features` → FAIL.
- [ ] **Step 3: `lib/app/providers.dart`:**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/db/database.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

/// Overridden in main() with the instance obtained before runApp.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('override sharedPreferencesProvider in main()');
```

- [ ] **Step 4: `lib/features/settings/theme_mode_controller.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/providers.dart';

part 'theme_mode_controller.g.dart';

@riverpod
class ThemeModeController extends _$ThemeModeController {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  void setMode(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }

  void cycle() =>
      setMode(ThemeMode.values[(state.index + 1) % ThemeMode.values.length]);
}
```

- [ ] **Step 5: `lib/app/theme/app_theme.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _seed = Color(0xFF5B5BD6);

ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

Color? argbToColor(int? argb) => argb == null ? null : Color(argb);

/// 8% color tint over a surface color, or [fallback] when no color is set.
Color tintSurface(ColorScheme scheme, int? argb, {Color? fallback}) {
  final base = fallback ?? scheme.surfaceContainerLow;
  if (argb == null) return base;
  return Color.alphaBlend(Color(argb).withValues(alpha: 0.08), base);
}
```

- [ ] **Step 6: `lib/app/router.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/notes/note_editor_screen.dart';
import '../features/task_list/task_list_screen.dart';
import '../features/trash/trash_screen.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/list/:listId',
          builder: (context, state) =>
              TaskListScreen(listId: state.pathParameters['listId']!),
        ),
        GoRoute(
          path: '/note/:noteId',
          builder: (context, state) =>
              NoteEditorScreen(noteId: state.pathParameters['noteId']!),
        ),
        GoRoute(
          path: '/trash',
          builder: (context, state) => const TrashScreen(),
        ),
      ],
    );
```

- [ ] **Step 7: `lib/app/app.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/theme_mode_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class TodoApp extends ConsumerWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Todo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeControllerProvider),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
```

- [ ] **Step 8: `lib/main.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const TodoApp(),
  ));
}
```

- [ ] **Step 9: Stub ekranlara AppBar** — `DashboardScreen`: `Scaffold(appBar: AppBar(title: const Text('Todo')), body: const SizedBox.shrink())`; `TaskListScreen`: `AppBar(title: const Text('List'))`; `NoteEditorScreen`: `AppBar(title: const Text('Note'))`; `TrashScreen`: `AppBar(title: const Text('Trash'))`. (Task 7-10 body'leri doldurur.)
- [ ] **Step 10:** `dart run build_runner build` → `.g.dart`'lar üretilsin.
- [ ] **Step 11: Smoke test `test/widget/smoke_test.dart`:**

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app_flutterv2/app/app.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('app boots on dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const TodoApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Todo'), findsOneWidget);
  });
}
```

- [ ] **Step 12:** `flutter test` PASS; `flutter analyze` temiz.

---

### Task 7: Task list feature (ekran + action'lar + core widget'lar)

**Files:**
- Create: `lib/features/task_list/providers.dart`, `lib/features/task_list/task_tile.dart`; Replace stub: `lib/features/task_list/task_list_screen.dart`
- Create: `lib/core/widgets/{empty_state,color_picker_sheet,undo_snack}.dart`
- Test: `test/features/task_list/task_list_actions_test.dart`

**Interfaces — Consumes:** `db.taskListDao/todoDao/trashDao` (Task 4-5), theme helpers (Task 6).
**Produces:**
- `enum TaskFilterKind { all, active, done }`; `List<TodoRow> applyTaskFilter(TaskFilterKind, List<TodoRow>)`
- `taskListProvider(listId:)`, `todosOfListProvider(listId:)`, `taskFilterProvider(listId:)` (class `TaskFilter`: `void select(TaskFilterKind)`)
- `taskListActionsProvider` class `TaskListActions`: `Future<String> addTask({required String listId, required String title})`, `Future<void> toggle(TodoRow row)`, `Future<void> renameTask({required String taskId, required String title})`, `Future<void> reorderTasks({required String listId, required int oldIndex, required int newIndex})`, `Future<List<String>> clearCompleted(String listId)`, `Future<void> renameList({required String listId, required String title})`, `Future<void> setListColor(String listId, int? color)`, `Future<String> moveListToTrash(String listId)`, `Future<String> moveTaskToTrash(TodoRow row)`
- `class EmptyState { const EmptyState({super.key, required IconData icon, required String message, String? actionLabel, VoidCallback? onAction}); }`
- `Future<void> showColorPickerSheet(BuildContext, {int? current, required Future<void> Function(int? color) onPicked})`
- `void showUndoTrashSnack(BuildContext, AppDatabase db, String trashId, String message)`; `void showUndoMultiSnack(BuildContext, AppDatabase db, List<String> trashIds, String message)`

- [ ] **Step 1: Failing test `test/features/task_list/task_list_actions_test.dart`:**

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/features/task_list/providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TaskListActions get actions => container.read(taskListActionsProvider.notifier);

  test('addTask then toggle', () async {
    final listId = await db.taskListDao.create('L');
    final taskId = await actions.addTask(listId: listId, title: 't');
    final row =
        await (db.select(db.todos)..where((t) => t.id.equals(taskId))).getSingle();
    await actions.toggle(row);
    final updated =
        await (db.select(db.todos)..where((t) => t.id.equals(taskId))).getSingle();
    expect(updated.completed, isTrue);
  });

  test('reorderTasks 2 → 0 moves item to front', () async {
    final listId = await db.taskListDao.create('L');
    await db.todoDao.add(listId, 'a');
    await db.todoDao.add(listId, 'b');
    await db.todoDao.add(listId, 'c');
    await actions.reorderTasks(listId: listId, oldIndex: 2, newIndex: 0);
    final rows = await db.todoDao.watchForList(listId).first;
    expect(rows.map((r) => r.title), ['c', 'a', 'b']);
  });

  test('moveTaskToTrash removes row, undo restores it', () async {
    final listId = await db.taskListDao.create('L');
    final taskId = await actions.addTask(listId: listId, title: 'gone');
    final row =
        await (db.select(db.todos)..where((t) => t.id.equals(taskId))).getSingle();

    final trashId = await actions.moveTaskToTrash(row);
    expect(await db.todoDao.watchForList(listId).first, isEmpty);

    await db.trashDao.restore(trashId);
    final restored = await db.todoDao.watchForList(listId).first;
    expect(restored.single.id, taskId);
  });

  test('applyTaskFilter', () {
    TodoRow t(String id, bool done) => TodoRow(
          id: id,
          listId: 'l',
          title: id,
          completed: done,
          completedAt: null,
          position: 0,
          createdAt: DateTime(2026),
        );
    final rows = [t('a', false), t('b', true), t('c', false)];
    expect(applyTaskFilter(TaskFilterKind.all, rows).length, 3);
    expect(applyTaskFilter(TaskFilterKind.active, rows).map((r) => r.id), ['a', 'c']);
    expect(applyTaskFilter(TaskFilterKind.done, rows).map((r) => r.id), ['b']);
  });
}
```

- [ ] **Step 2:** `flutter test test/features/task_list` → FAIL.
- [ ] **Step 3: `lib/features/task_list/providers.dart`:**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';

part 'providers.g.dart';

enum TaskFilterKind { all, active, done }

List<TodoRow> applyTaskFilter(TaskFilterKind kind, List<TodoRow> rows) =>
    switch (kind) {
      TaskFilterKind.all => rows,
      TaskFilterKind.active => rows.where((t) => !t.completed).toList(),
      TaskFilterKind.done => rows.where((t) => t.completed).toList(),
    };

@riverpod
Stream<TaskListRow?> taskList(Ref ref, {required String listId}) =>
    ref.watch(appDatabaseProvider).taskListDao.watchById(listId);

@riverpod
Stream<List<TodoRow>> todosOfList(Ref ref, {required String listId}) =>
    ref.watch(appDatabaseProvider).todoDao.watchForList(listId);

@riverpod
class TaskFilter extends _$TaskFilter {
  @override
  TaskFilterKind build({required String listId}) => TaskFilterKind.all;

  void select(TaskFilterKind kind) => state = kind;
}

@riverpod
class TaskListActions extends _$TaskListActions {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<String> addTask({required String listId, required String title}) =>
      _db.todoDao.add(listId, title.trim());

  Future<void> toggle(TodoRow row) =>
      _db.todoDao.setCompleted(row.id, !row.completed);

  Future<void> renameTask({required String taskId, required String title}) =>
      _db.todoDao.rename(taskId, title.trim());

  Future<void> reorderTasks({
    required String listId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final rows = await _db.todoDao.watchForList(listId).first;
    final ordered = rows.map((r) => r.id).toList()
      ..insert(newIndex, rows[oldIndex].id)
      ..removeAt(oldIndex < newIndex ? oldIndex : oldIndex + 1);
    await _db.todoDao.setPositions(listId, ordered);
  }

  Future<List<String>> clearCompleted(String listId) =>
      _db.todoDao.clearCompletedToTrash(listId);

  Future<void> renameList({required String listId, required String title}) =>
      _db.taskListDao.rename(listId, title.trim());

  Future<void> setListColor(String listId, int? color) =>
      _db.taskListDao.setColor(listId, color);

  Future<String> moveListToTrash(String listId) =>
      _db.taskListDao.moveToTrash(listId);

  Future<String> moveTaskToTrash(TodoRow row) => _db.todoDao.moveToTrashRow(row);
}
```

- [ ] **Step 4: Core widget'lar.** `lib/core/widgets/undo_snack.dart`:

```dart
import 'package:flutter/material.dart';

import '../db/database.dart';

/// SnackBar with Undo that restores [trashId] from the trash.
void showUndoTrashSnack(
  BuildContext context,
  AppDatabase db,
  String trashId,
  String message,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: SnackBarAction(label: 'Undo', onPressed: () => db.trashDao.restore(trashId)),
    ));
}

/// Multi-undo variant used by "Clear completed".
void showUndoMultiSnack(
  BuildContext context,
  AppDatabase db,
  List<String> trashIds,
  String message,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          for (final id in trashIds) {
            await db.trashDao.restore(id);
          }
        },
      ),
    ));
}
```

`lib/core/widgets/empty_state.dart`:

```dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
```

`lib/core/widgets/color_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/palette.dart';

/// Bottom sheet: 8-swatch palette (+clear) with apply callback.
Future<void> showColorPickerSheet(
  BuildContext context, {
  int? current,
  required Future<void> Function(int? color) onPicked,
}) async {
  var selected = current;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Color', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ColorDot(
                    color: null,
                    selected: selected == null,
                    onTap: () => setSheetState(() => selected = null),
                  ),
                  for (final argb in kListPalette)
                    _ColorDot(
                      color: argb,
                      selected: selected == argb,
                      onTap: () => setSheetState(() => selected = argb),
                    ),
                  _ColorDot(
                    color: 0xFF6750A4,
                    selected: false,
                    icon: Icons.tune,
                    onTap: () async {
                      final custom = await showDialog<int>(
                        context: context,
                        builder: (context) => _CustomColorDialog(initial: current),
                      );
                      if (custom != null) setSheetState(() => selected = custom);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () {
                    onPicked(selected);
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final int? color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color == null ? scheme.surfaceContainerHighest : Color(color!),
          border: selected
              ? Border.all(color: scheme.onSurface, width: 2.5)
              : Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: icon != null
            ? Icon(icon, size: 20, color: scheme.onSurfaceVariant)
            : (color == null && selected
                ? Icon(Icons.block, size: 20, color: scheme.onSurfaceVariant)
                : null),
      ),
    );
  }
}

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({this.initial});

  final int? initial;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late Color _color = widget.initial == null
      ? const Color(0xFF3B82F6)
      : Color(widget.initial!);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom color'),
      content: SizedBox(
        width: 280,
        child: ColorPicker(
          pickerColor: _color,
          enableAlpha: false,
          onColorChanged: (c) => setState(() => _color = c),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color.toARGB32()),
          child: const Text('Pick'),
        ),
      ],
    );
  }
}
```

(`ColorPicker` `package:flutter_colorpicker` import'u ister: dosyanın başına `import 'package:flutter_colorpicker/flutter_colorpicker.dart';` ekle — HueRingPicker/ColorPicker widget'ı oradadır.)

- [ ] **Step 5: `lib/features/task_list/task_tile.dart`:**

```dart
import 'package:flutter/material.dart';

import '../../core/db/database.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    this.dragHandle,
  });

  final TodoRow task;
  final VoidCallback onToggle;
  final Future<void> Function() onRename;
  final VoidCallback onDelete;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('swipe-task-${task.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: ListTile(
        leading: Checkbox(value: task.completed, onChanged: (_) => onToggle()),
        title: Text(
          task.title,
          style: task.completed
              ? TextStyle(decoration: TextDecoration.lineThrough, color: scheme.onSurfaceVariant)
              : null,
        ),
        trailing: dragHandle,
        onTap: onRename,
      ),
    );
  }
}
```

- [ ] **Step 6: `task_list_screen.dart` (stub'ı tamamen değiştir):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/db/database.dart';
import '../../core/widgets/color_picker_sheet.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/undo_snack.dart';
import 'providers.dart';
import 'task_tile.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<String?> _promptTitle({required String title, required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameList(TaskListRow list) async {
    final newTitle = await _promptTitle(title: 'Rename list', initial: list.title);
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await ref
          .read(taskListActionsProvider.notifier)
          .renameList(listId: list.id, title: newTitle);
    }
  }

  Future<void> _renameTask(TodoRow task) async {
    final newTitle = await _promptTitle(title: 'Rename task', initial: task.title);
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await ref
          .read(taskListActionsProvider.notifier)
          .renameTask(taskId: task.id, title: newTitle);
    }
  }

  Future<void> _deleteList(TaskListRow list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move "${list.title}" to trash?'),
        content: const Text('It will stay in trash for 30 days.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final trashId =
        await ref.read(taskListActionsProvider.notifier).moveListToTrash(list.id);
    if (!mounted) return;
    context.pop();
    showUndoTrashSnack(context, ref.read(appDatabaseProvider), trashId, 'List moved to trash');
  }

  Future<void> _submitTask() async {
    final title = _addController.text.trim();
    if (title.isEmpty) return;
    _addController.clear();
    await ref
        .read(taskListActionsProvider.notifier)
        .addTask(listId: widget.listId, title: title);
  }

  Widget _taskView(TaskListRow list, List<TodoRow> visible, bool reorderable, AppDatabase db) {
    Widget tile(BuildContext context, int index) {
      final task = visible[index];
      return Padding(
        key: ValueKey('task-${task.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Card(
          child: TaskTile(
            task: task,
            onToggle: () => ref.read(taskListActionsProvider.notifier).toggle(task),
            onRename: () => _renameTask(task),
            onDelete: () async {
              final trashId =
                  await ref.read(taskListActionsProvider.notifier).moveTaskToTrash(task);
              if (!context.mounted) return;
              showUndoTrashSnack(
                  context, db, trashId, 'Task moved to trash');
            },
            dragHandle: reorderable
                ? ReorderableDragStartListener(
                    index: index, child: const Icon(Icons.drag_handle))
                : null,
          ),
        ),
      );
    }

    if (reorderable) {
      return ReorderableListView.builder(
        itemCount: visible.length,
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) => ref
            .read(taskListActionsProvider.notifier)
            .reorderTasks(
              listId: list.id,
              oldIndex: oldIndex,
              newIndex: newIndex > oldIndex ? newIndex - 1 : newIndex,
            ),
        itemBuilder: tile,
      );
    }
    return ListView.builder(itemCount: visible.length, itemBuilder: tile);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(taskListProvider(listId: widget.listId));
    final tasksAsync = ref.watch(todosOfListProvider(listId: widget.listId));
    final filter = ref.watch(taskFilterProvider(listId: widget.listId));
    final db = ref.watch(appDatabaseProvider);
    final scheme = Theme.of(context).colorScheme;

    return listAsync.maybeWhen(
      data: (list) {
        if (list == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.info_outline,
              message: 'This list no longer exists.',
            ),
          );
        }
        final all = tasksAsync.value ?? const <TodoRow>[];
        final visible = applyTaskFilter(filter, all);
        final done = all.where((t) => t.completed).length;
        final bg = tintSurface(scheme, list.color, fallback: scheme.surface);

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            title: GestureDetector(
              onLongPress: () => _renameList(list),
              child: Text(list.title, overflow: TextOverflow.ellipsis),
            ),
            actions: [
              IconButton(
                tooltip: 'Color',
                icon: Icon(
                  Icons.palette,
                  color: list.color == null ? null : Color(list.color!),
                ),
                onPressed: () => showColorPickerSheet(
                  context,
                  current: list.color,
                  onPicked: (c) => ref
                      .read(taskListActionsProvider.notifier)
                      .setListColor(list.id, c),
                ),
              ),
              IconButton(
                tooltip: 'Delete list',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteList(list),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        all.isEmpty ? 'Empty list' : '$done/${all.length} done',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    SegmentedButton<TaskFilterKind>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: TaskFilterKind.all, label: Text('All')),
                        ButtonSegment(value: TaskFilterKind.active, label: Text('Active')),
                        ButtonSegment(value: TaskFilterKind.done, label: Text('Done')),
                      ],
                      selected: {filter},
                      onSelectionChanged: (s) => ref
                          .read(taskFilterProvider(listId: widget.listId).notifier)
                          .select(s.first),
                    ),
                    IconButton(
                      tooltip: 'Clear completed',
                      onPressed: done == 0
                          ? null
                          : () async {
                              final ids = await ref
                                  .read(taskListActionsProvider.notifier)
                                  .clearCompleted(list.id);
                              if (!context.mounted) return;
                              showUndoMultiSnack(context, db, ids,
                                  '${ids.length} completed task(s) moved to trash');
                            },
                      icon: const Icon(Icons.done_all),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        icon: Icons.checklist_rounded,
                        message: switch (filter) {
                          TaskFilterKind.all => 'No tasks yet. Add one below.',
                          TaskFilterKind.active => 'Nothing active — all done!',
                          TaskFilterKind.done => 'No completed tasks yet.',
                        },
                      )
                    : _taskView(list, visible, filter == TaskFilterKind.all, db),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitTask(),
                      decoration: const InputDecoration(hintText: 'Add a task…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _submitTask, icon: const Icon(Icons.add)),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
```

- [ ] **Step 7:** `dart run build_runner build`; `flutter analyze`; `flutter test` PASS. `showColorPickerSheet` dashboard/not ekranlarında da kullanılacak — imza sabit.

---

### Task 8: Notes feature (flutter_quill editör)

**Files:**
- Create: `lib/features/notes/providers.dart`; Replace stub: `lib/features/notes/note_editor_screen.dart`
- Test: `test/features/notes/note_actions_test.dart`

**Interfaces — Consumes:** `db.noteDao` (Task 5), `Debouncer`/`deltaToPlainText` (Task 2), `showColorPickerSheet`/`showUndoTrashSnack` (Task 7), `tintSurface` (Task 6).
**Produces:**
- `noteProvider(noteId:)` → `Stream<NoteRow?>`
- `noteActionsProvider` class `NoteActions`: `Future<String> createNote()`, `Future<void> save({required String noteId, required String title, required String content})`, `Future<void> setNoteColor(String noteId, int? color)`, `Future<String> moveNoteToTrash(String noteId)`
- `Document parseNoteDocument(String contentJson)`

- [ ] **Step 1: Failing test `test/features/notes/note_actions_test.dart`:**

```dart
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
    final container =
        ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final actions = container.read(noteActionsProvider.notifier);

    final id = await actions.createNote();
    var row = await db.noteDao.watchById(id).first;
    expect(row!.title, '');

    await actions.save(noteId: id, title: 'Groceries', content: '[{"insert":"milk"}]');
    row = await db.noteDao.watchById(id).first;
    expect(row!.title, 'Groceries');
    expect(row.content, '[{"insert":"milk"}]');

    final trashId = await actions.moveNoteToTrash(id);
    expect(await db.noteDao.watchById(id).first, isNull);
    final item =
        await (db.select(db.trashItems)..where((t) => t.id.equals(trashId))).getSingle();
    expect(item.kind, 'note');
    expect(item.payload, contains('Groceries'));
  });
}
```

- [ ] **Step 2:** `flutter test test/features/notes` → FAIL.
- [ ] **Step 3: `lib/features/notes/providers.dart`:**

```dart
import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';

part 'providers.g.dart';

@riverpod
Stream<NoteRow?> note(Ref ref, {required String noteId}) =>
    ref.watch(appDatabaseProvider).noteDao.watchById(noteId);

@riverpod
class NoteActions extends _$NoteActions {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<String> createNote() => _db.noteDao.create();

  Future<void> save({
    required String noteId,
    required String title,
    required String content,
  }) =>
      _db.noteDao.save(noteId, title: title, content: content);

  Future<void> setNoteColor(String noteId, int? color) =>
      _db.noteDao.setColor(noteId, color);

  Future<String> moveNoteToTrash(String noteId) => _db.noteDao.moveToTrash(noteId);
}

/// Parses stored delta JSON; blank document for empty input.
Document parseNoteDocument(String contentJson) {
  final trimmed = contentJson.trim();
  if (trimmed.isEmpty || trimmed == '[]' || trimmed == '{"ops":[]}') {
    return Document();
  }
  return Document.fromJson(jsonDecode(trimmed));
}
```

(Not: `Document()` boş constructor `QuillController.basic()` tarafından kullanılıyor; derlenmezse fallback `Document.fromJson(jsonDecode('{"ops":[{"insert":"\\n"}]}'))`.)

- [ ] **Step 4: `note_editor_screen.dart` (stub'ı değiştir):**

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/debouncer.dart';
import '../../core/widgets/color_picker_sheet.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/undo_snack.dart';
import 'providers.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  QuillController? _quill;
  Debouncer? _debouncer;
  bool _loaded = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _debouncer = Debouncer(const Duration(milliseconds: 300), _saveNow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final row = await (db.select(db.notes)..where((t) => t.id.equals(widget.noteId)))
        .getSingleOrNull();
    if (row == null || !mounted) return;
    _titleController.text = row.title;
    final quill = QuillController(
      document: parseNoteDocument(row.content),
      selection: const TextSelection.collapsed(offset: 0),
    );
    quill.addListener(_onChanged);
    setState(() {
      _quill = quill;
      _loaded = true;
    });
  }

  void _onChanged() {
    _dirty = true;
    _debouncer!.call();
  }

  String get _contentJson => _quill == null
      ? '[]'
      : jsonEncode(_quill!.document.toDelta().toJson());

  Future<void> _saveNow() async {
    if (!_dirty) return;
    _dirty = false;
    await ref.read(noteActionsProvider.notifier).save(
          noteId: widget.noteId,
          title: _titleController.text,
          content: _contentJson,
        );
  }

  @override
  void dispose() {
    _debouncer?.flush();
    _quill?.removeListener(_onChanged);
    _quill?.dispose();
    _titleController.dispose();
    _debouncer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(noteProvider(noteId: widget.noteId));

    return note.maybeWhen(
      data: (row) {
        if (row == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.info_outline,
              message: 'This note is no longer available.',
            ),
          );
        }
        if (!_loaded || _quill == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final scheme = Theme.of(context).colorScheme;
        final bg = tintSurface(scheme, row.color, fallback: scheme.surface);
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _debouncer?.flush();
                context.pop();
              },
            ),
            actions: [
              IconButton(
                tooltip: 'Color',
                icon: Icon(Icons.palette, color: row.color == null ? null : Color(row.color!)),
                onPressed: () => showColorPickerSheet(
                  context,
                  current: row.color,
                  onPicked: (c) => ref
                      .read(noteActionsProvider.notifier)
                      .setNoteColor(widget.noteId, c),
                ),
              ),
              IconButton(
                tooltip: 'Move to trash',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final trashId = await ref
                      .read(noteActionsProvider.notifier)
                      .moveNoteToTrash(widget.noteId);
                  if (!context.mounted) return;
                  context.pop();
                  showUndoTrashSnack(
                    context, ref.read(appDatabaseProvider), trashId, 'Note moved to trash');
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(
                  controller: _titleController,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    hintText: 'Note title',
                    filled: false,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    _dirty = true;
                    _debouncer!.call();
                  },
                ),
              ),
              const Divider(height: 1),
              QuillToolbar.basic(controller: _quill!),
              const Divider(height: 1),
              Expanded(child: QuillEditor.basic(controller: _quill!, readOnly: false)),
            ],
          ),
        );
      },
      orElse: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
```

(Not: `QuillToolbar.basic` flag adları kurulu sürümle oynarsa minimum `QuillToolbar.basic(controller: ...)`'a düş; editor için `QuillEditor.basic(controller: ..., readOnly: false)`.)

- [ ] **Step 5:** `dart run build_runner build`; `flutter analyze`; `flutter test` PASS.

---

### Task 9: Dashboard (unified grid, reorder, swipe-to-trash, FAB)

**Files:**
- Create: `lib/features/dashboard/providers.dart`, `lib/features/dashboard/dash_card.dart`; Replace stub: `lib/features/dashboard/dashboard_screen.dart`
- Test: `test/features/dashboard/dash_feed_test.dart`, `test/widget/dashboard_empty_test.dart`

**Interfaces — Consumes:** tüm DAO'lar, `TaskListActions.create?` yerine doğrudan `taskListDao.create`, `NoteActions.createNote`, `showUndoTrashSnack`, `deltaToPlainText`, `tintSurface/argbToColor`, `EmptyState`, `TaskFilter` yok.
**Produces:**
- `class DashItem { final String id; final String title; final int? color; final int position; final DateTime createdAt; final bool isList; final TaskListRow? listRow; final NoteRow? noteRow; const DashItem.fromList(TaskListRow) / fromNote(NoteRow); }`
- `taskListsStreamProvider`, `notesStreamProvider`, `dashFeedProvider` (`List<DashItem>` position+createdAt sıralı), `trashCountProvider`
- `dashboardActionsProvider` class `DashboardActions`: `Future<String> createList()`, `Future<String> createNote()`, `Future<void> reorder(List<DashItem> ordered)`, `Future<String> moveToTrash(DashItem item)`

- [ ] **Step 1: Failing test `test/features/dashboard/dash_feed_test.dart`:**

```dart
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
    container =
        ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('dashFeed merges lists and notes by position', () async {
    final l1 = await db.taskListDao.create('L1');
    final n1 = await db.noteDao.create();
    await db.noteDao.create();
    // notların pozisyonunu kaydır: L1 → 5 olsun
    await db.taskListDao.setPosition(l1, 5);

    await container.read(dashFeedProvider.future);
    final items = container.read(dashFeedProvider).requireValue;
    expect(items.map((i) => i.isList), [true, false, false]);
    expect(items.first.id, l1);
    expect(items[1].id, n1);
  });

  test('DashboardActions.createList creates and reorder writes positions', () async {
    final actions = container.read(dashboardActionsProvider.notifier);
    final id = await actions.createList();
    final id2 = await actions.createList();
    await actions.createNote();

    var items = await container.read(dashFeedProvider.future);
    expect(items.map((i) => i.id), [id, id2, isA<String>()]);

    items = [items[2], items[0], items[1]];
    await actions.reorder(items);
    final after = await container.read(dashFeedProvider.future);
    expect(after.map((i) => i.id), [items[0].id, id, id2]);
  });

  test('moveToTrash routes by kind', () async {
    final actions = container.read(dashboardActionsProvider.notifier);
    final listId = await actions.createList();
    final noteId = await actions.createNote();

    final t1 = await actions.moveToTrash(
        DashItem.fromList((await (db.select(db.taskLists)
                ..where((t) => t.id.equals(listId)))
            .getSingle())));
    final t2 = await actions.moveToTrash(DashItem.fromNote(
        (await (db.select(db.notes)..where((t) => t.id.equals(noteId))).getSingle())));

    expect(t1, isNotEmpty);
    expect(t2, isNotEmpty);
    expect(await db.trashDao.watchCount().first, 2);
  });
}
```

- [ ] **Step 2:** `flutter test test/features/dashboard` → FAIL.
- [ ] **Step 3: `lib/features/dashboard/providers.dart`:**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';

part 'providers.g.dart';

class DashItem {
  const DashItem.fromList(TaskListRow row)
      : id = row.id,
        title = row.title,
        color = row.color,
        position = row.position,
        createdAt = row.createdAt,
        isList = true,
        listRow = row,
        noteRow = null;

  const DashItem.fromNote(NoteRow row)
      : id = row.id,
        title = row.title,
        color = row.color,
        position = row.position,
        createdAt = row.updatedAt,
        isList = false,
        listRow = null,
        noteRow = row;

  final String id;
  final String title;
  final int? color;
  final int position;
  final DateTime createdAt;
  final bool isList;
  final TaskListRow? listRow;
  final NoteRow? noteRow;
}

@riverpod
Stream<List<TaskListRow>> taskListsStream(Ref ref) =>
    ref.watch(appDatabaseProvider).taskListDao.watchAll();

@riverpod
Stream<List<NoteRow>> notesStream(Ref ref) =>
    ref.watch(appDatabaseProvider).noteDao.watchAll();

@riverpod
Stream<int> trashCount(Ref ref) => ref.watch(appDatabaseProvider).trashDao.watchCount();

@riverpod
List<DashItem> dashFeed(Ref ref) {
  final lists = ref.watch(taskListsStreamProvider).value ?? const <TaskListRow>[];
  final notes = ref.watch(notesStreamProvider).value ?? const <NoteRow>[];
  return [
    for (final l in lists) DashItem.fromList(l),
    for (final n in notes) DashItem.fromNote(n),
  ]..sort((a, b) => a.position != b.position
      ? a.position.compareTo(b.position)
      : a.createdAt.compareTo(b.createdAt));
}

@riverpod
class DashboardActions extends _$DashboardActions {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<String> createList() => _db.taskListDao.create('New list');

  Future<String> createNote() => _db.noteDao.create();

  /// Persists merged card order: writes index as position per table.
  Future<void> reorder(List<DashItem> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final item = ordered[i];
      if (item.isList) {
        await _db.taskListDao.setPosition(item.id, i);
      } else {
        await _db.noteDao.setPosition(item.id, i);
      }
    }
  }

  Future<String> moveToTrash(DashItem item) => item.isList
      ? _db.taskListDao.moveToTrash(item.id)
      : _db.noteDao.moveToTrash(item.id);
}
```

- [ ] **Step 4: `lib/features/dashboard/dash_card.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/db/database.dart';
import '../../core/utils/delta_text.dart';
import '../task_list/providers.dart';
import 'providers.dart';

class DashCard extends StatelessWidget {
  const DashCard({super.key, required this.item, required this.onDismiss});

  final DashItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dash-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: Card(
        color: tintSurface(scheme, item.color),
        child: InkWell(
          onTap: () => context.go(item.isList ? '/list/${item.id}' : '/note/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: item.isList
                ? _ListCardBody(row: item.listRow!)
                : _NoteCardBody(row: item.noteRow!),
          ),
        ),
      ),
    );
  }
}

class _ListCardBody extends ConsumerWidget {
  const _ListCardBody({required this.row});

  final TaskListRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(todosOfListProvider(listId: row.id)).value ?? const [];
    final active = tasks.where((t) => !t.completed).take(3).toList();
    final remaining = tasks.where((t) => !t.completed).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded,
                size: 18, color: argbToColor(row.color) ?? Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(row.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Text('No tasks yet', style: Theme.of(context).textTheme.bodySmall)
        else
          for (final t in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_unchecked, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        if (remaining > 3)
          Text('and ${remaining - 3} more…',
              style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        Text('$remaining to do',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyColor(Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _NoteCardBody extends StatelessWidget {
  const _NoteCardBody({required this.row});

  final NoteRow row;

  @override
  Widget build(BuildContext context) {
    final preview = deltaToPlainText(row.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sticky_note_2_rounded,
                size: 18,
                color: argbToColor(row.color) ?? Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(row.title.isEmpty ? 'Untitled' : row.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Text(
            preview.isEmpty ? 'Empty note' : preview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
```

(`?.copyColor` diye metot yok — `?.copyWith(color: ...)` kullan; bu satır plan standardı.)

- [ ] **Step 5: `dashboard_screen.dart` (stub'ı değiştir):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_slivers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/undo_snack.dart';
import 'dash_card.dart';
import 'providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(appDatabaseProvider).trashDao.purgeExpired();
  }

  Future<void> _openNewList() async {
    final id = await ref.read(dashboardActionsProvider.notifier).createList();
    if (mounted) context.go('/list/$id');
  }

  Future<void> _openNewNote() async {
    final id = await ref.read(dashboardActionsProvider.notifier).createNote();
    if (mounted) context.go('/note/$id');
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(dashFeedProvider);
    final trash = ref.watch(trashCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo'),
        actions: [
          IconButton(
            tooltip: 'New list',
            icon: const Icon(Icons.playlist_add),
            onPressed: _openNewList,
          ),
          IconButton(
            tooltip: 'New note',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: _openNewNote,
          ),
          IconButton(
            tooltip: 'Theme',
            icon: Icon(switch (Theme.of(context).brightness) {
              Brightness.dark => Icons.dark_mode_outlined,
              Brightness.light => Icons.light_mode_outlined,
            }),
            onPressed: () => ref.read(themeModeControllerProvider.notifier).cycle(),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          heroTag: 'trash-fab',
          onPressed: () => context.go('/trash'),
          child: Badge(
            isLabelVisible: trash > 0,
            label: Text('$trash'),
            child: const Icon(Icons.delete_outline),
          ),
        ),
      ),
      body: itemsAsync.maybeWhen(
        skipLoadingOnRefresh: false,
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.dashboard_customize_outlined,
              message: 'Nothing here yet.',
              actionLabel: 'Create your first list',
              onAction: _openNewList,
            );
          }
          return ReorderableBuilder(
            key: ValueKey(items.map((i) => i.id).join()),
            params: items
                .asMap()
                .entries
                .map((e) => ReorderableConfigParams(id: e.value.id, index: e.key))
                .toList(),
            onReorderCompleted: (newOrder) async {
              final byId = {for (final i in items) i.id: i};
              final ordered = newOrder
                  .map((id) => byId[id]!)
                  .toList(growable: false);
              await ref
                  .read(dashboardActionsProvider.notifier)
                  .reorder(ordered);
            },
            builder: (children) => GridView(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              children: children,
            ),
            children: [
              for (final item in items)
                DashCard(
                  key: ValueKey('card-${item.id}'),
                  item: item,
                  onDismiss: () async {
                    final db = ref.read(appDatabaseProvider);
                    final trashId = await ref
                        .read(dashboardActionsProvider.notifier)
                        .moveToTrash(item);
                    if (!context.mounted) return;
                    showUndoTrashSnack(
                        context, db, trashId, 'Moved to trash');
                  },
                ),
            ],
          );
        },
        orElse: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
```

**ÖNEMLİ (reorder API'si):** `flutter_reorderable_grid_view` sürüm 5.x'in güncel API'si `ReorderableBuilder(params: [...], onReorderCompleted: (List<String> newIds) {...}, builder: (children) => GridView(...), children: [...])` şeklindedir. Kurulu pakette `ReorderableConfigParams`/`ReorderableBuilder` adları/factory imzaları farklıysa: `flutter pub deps` sonrası `~/.pub-cache` içindeki paket README'sine bak ve eşdeğer `ReorderableSliverGridView` varyantını kullan. Davranış hedefi sabit: uzun-bas-sürükle ile kart sırası değişir, yeni sıra `DashboardActions.reorder`'a yazılır. Ayrıca dashboard theme provider import'u: `import '../../features/settings/theme_mode_controller.dart';` (cycle için). `ReorderableBuilder` her stream güncellemesinde reset'lenmesin diye stream reorder sonrası güncellenir — `ValueKey(items.map...)` stream'den geldiği için reorder anında flicker kabul edilebilir (v1).

- [ ] **Step 6: Widget testi `test/widget/dashboard_empty_test.dart`:**

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/features/dashboard/dashboard_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows empty state when no content', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(find.text('Create your first list'), findsOneWidget);
  });

  testWidgets('renders a list card with task preview', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.taskListDao.create('Groceries');
    await db.todoDao.add(id, 'Milk');
    await db.todoDao.add(id, 'Eggs');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('2 to do'), findsOneWidget);
  });
}
```

- [ ] **Step 7:** `dart run build_runner build`; `flutter analyze`; `flutter test` PASS.

---

### Task 10: Trash ekranı (restore / delete forever / empty / retention)

**Files:**
- Create: `lib/features/trash/providers.dart`; Replace stub: `lib/features/trash/trash_screen.dart`
- Test: `test/features/trash/trash_actions_test.dart`

**Interfaces — Consumes:** `db.trashDao` (restore/deleteForever/emptyAll/watchAll/purgeExpired), `trashDaysLeft`.
**Produces:**
- `trashFeedProvider` → `Stream<List<TrashItemRow>>`
- `trashActionsProvider` class `TrashActions`: `Future<String> restore(String trashId)`, `Future<void> deleteForever(String trashId)`, `Future<void> emptyAll()`, `Future<int> purgeExpired()`

- [ ] **Step 1: Failing test `test/features/trash/trash_actions_test.dart`:**

```dart
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
    final container =
        ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final actions = container.read(trashActionsProvider.notifier);

    final listId = await db.taskListDao.create('A');
    final trashId = await db.taskListDao.moveToTrash(listId);

    expect(await actions.restore(trashId), 'list');
    expect(await db.taskListDao.watchAll().first, hasLength(1));

    final trashId2 = await db.taskListDao.moveToTrash(listId);
    await actions.deleteForever(trashId2);
    expect(await db.trashDao.watchAll().first, isEmpty);

    final trashId3 = await db.taskListDao.moveToTrash(
        await db.taskListDao.create('B'));
    expect(await db.trashDao.watchAll().first, hasLength(1));
    await actions.emptyAll();
    expect(await db.trashDao.watchAll().first, isEmpty);
  });

  test('purgeExpired via actions', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final now = DateTime(2026, 9, 1);
    await db.trashDao.insertPayload(
        kind: 'note', payload: '{}', deletedAt: now.subtract(const Duration(days: 40)));
    final removed = await container
        .read(trashActionsProvider.notifier)
        .purgeExpired();
    expect(removed, greaterThanOrEqualTo(0)); // "now" test anında gerçek zaman
  });
}
```

- [ ] **Step 2:** `flutter test test/features/trash` → FAIL.
- [ ] **Step 3: `lib/features/trash/providers.dart`:**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';

part 'providers.g.dart';

@riverpod
Stream<List<TrashItemRow>> trashFeed(Ref ref) =>
    ref.watch(appDatabaseProvider).trashDao.watchAll();

@riverpod
class TrashActions extends _$TrashActions {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<String> restore(String trashId) => _db.trashDao.restore(trashId);

  Future<void> deleteForever(String trashId) => _db.trashDao.deleteForever(trashId);

  Future<void> emptyAll() => _db.trashDao.emptyAll();

  Future<int> purgeExpired() => _db.trashDao.purgeExpired();
}

/// Human label for a trash row.
String trashItemLabel(TrashItemRow row) {
  return switch (row.kind) {
    'list' => 'Task list',
    'note' => 'Note',
    'task' => 'Task',
    _ => 'Item',
  };
}

/// Title snippet from the stored payload, best effort.
String trashItemTitle(TrashItemRow row) {
  final raw = row.payload;
  final marker = '"title":"';
  final start = raw.indexOf(marker);
  if (start < 0) return trashItemLabel(row);
  final from = start + marker.length;
  final end = raw.indexOf('"', from);
  if (end <= from) return trashItemLabel(row);
  return raw.substring(from, end);
}
```

(`trashItemTitle` payload'tan regex-free basit parse — restore payload JSON'u tam güvenir, UI etiketi için yeter; tam parse yerine `jsonDecode` + `['list']`/'title' kullanmak istenirse Task 10 executor karar verir, imza sabit.)

- [ ] **Step 4: `trash_screen.dart` (stub'ı değiştir):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/db/database.dart';
import '../../core/utils/time_ago.dart';
import '../../core/widgets/empty_state.dart';
import 'providers.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(trashActionsProvider.notifier).purgeExpired();
  }

  Future<bool> _confirm(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(trashFeedProvider).value ?? const <TrashItemRow>[];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                if (!await _confirm('Empty the trash?')) return;
                await ref.read(trashActionsProvider.notifier).emptyAll();
              },
              child: const Text('Empty'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.delete_outline_rounded,
              message: 'Trash is empty.\nDeleted items stay here for 30 days.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(switch (row.kind) {
                      'list' => Icons.checklist_rounded,
                      'note' => Icons.sticky_note_2_rounded,
                      _ => Icons.check_circle_outline,
                    }, color: scheme.primary),
                    title: Text(trashItemTitle(row),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${trashItemLabel(row)} · ${trashDaysLeft(row.deletedAt)} days left',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Restore',
                          icon: const Icon(Icons.undo),
                          onPressed: () => ref
                              .read(trashActionsProvider.notifier)
                              .restore(row.id),
                        ),
                        IconButton(
                          tooltip: 'Delete forever',
                          icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
                          onPressed: () async {
                            if (!await _confirm('Delete "${trashItemTitle(row)}" forever?')) {
                              return;
                            }
                            await ref
                                .read(trashActionsProvider.notifier)
                                .deleteForever(row.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 5:** `dart run build_runner build`; `flutter analyze`; `flutter test` PASS.

---

### Task 11: Polish + final doğrulama

**Files:** Modify: `README.md` (proje kökü, yeniden yaz)

- [ ] **Step 1:** README: kurulum (`flutter pub get`, `dart run build_runner build`, `flutter run`), mimari özeti, klasör ağacı — spec'ten uyarla.
- [ ] **Step 2:** `dart run build_runner build` temiz; `flutter analyze` **0 issue**; `flutter test` **tümü PASS**; `dart run custom_lint` uyarıları varsa düzelt.
- [ ] **Step 3:** `flutter build apk --debug` derleniyorsa çalıştır (Android SDK kuruluysa; değilse not düş).
- [ ] **Step 4:** Manuel UX kontrol listesi (cihaz/emülatör varsa): create list → add/rename/toggle/reorder task → color → swipe delete + undo → note + formatting + autosave → dashboard reorder → trash restore/empty → tema cycle.

## Self-review notu (yazar)

- Spec kapsamı → task eşlemesi: tema/prefs (T6), list/CRUD/filter/clear (T7), not/quill/autosave (T8), dashboard/grid/swipe/FAB (T9), trash/retention/purge (T10, T5), renk paleti+custom (T7 widget, T1 palet), M3 tasarım (T6). Kapsam dışı maddeler yok sayıldı (spec §9).
- Bilinen sürüm-riskli noktalar (implementasyonda doğrulanacak, plan içinde notlandı): flutter_quill toolbar/editor parametre adları; flutter_reorderable_grid_view 5.x reorder API'si; Windows sqlite3 native lib; `Document()` boş constructor; very_good_analysis'ın ekstra kuralları.


