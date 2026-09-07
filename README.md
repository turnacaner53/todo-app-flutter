# Todos — a Flutter Android app

**Todos** is a local-first to-do and notes app for **Android**, built with
Flutter. It keeps task lists and rich text notes on your device (SQLite) —
no account, no server, no internet required. Deleted items wait in a shared
30-day trash, cards are color-tinted and drag-to-reorder, and the UI follows
your system light/dark theme.

This project is the **Flutter clone of `todo-app`** (the Next.js version at
`D:\_PROJECTS\qwen3.8-test-project\todo-app`): the same product, rebuilt on a
native mobile stack — IndexedDB/Dexie became drift/SQLite, React state became
Riverpod, Tiptap became flutter_quill. It also doubles as a test bed for
**Qwen3.8 27B** running locally as a coding agent.

## Download (Android APK)

Grab the latest release build from the
[**Releases page → v1.0.0**](https://github.com/turnacaner53/todo-app-flutter/releases/tag/v1.0.0):

| APK | For |
|---|---|
| `Todos-arm64-v8a.apk` (≈22 MB) | most modern phones — **pick this one** |
| `Todos-armeabi-v7a.apk` (≈20 MB) | older 32-bit devices |
| `Todos-x86_64.apk` (≈23 MB) | Android emulators |
| `Todos-universal.apk` (≈63 MB) | fallback, all ABIs |

Enable *Install unknown apps* in Android settings, then open the APK. The
build is signed with a debug keystore — fine for sideloading and evaluation,
not for Play Store distribution.

## Stack

Flutter 3.41 · Dart 3.11 · Riverpod 3 (hand-written providers) · drift 2.34
(SQLite) · go_router · flutter_quill 11 (WYSIWYG notes) ·
flutter_reorderable_grid_view · shared_preferences · google_fonts (Inter) ·
flutter_colorpicker · uuid · very_good_analysis

## Run it

```bash
flutter pub get
dart run build_runner build    # regenerates drift code (*.g.dart)
flutter run -d <device>
```

Then launch it on an Android device or emulator (`flutter emulators` to
start one).

Verification:

```bash
flutter analyze
flutter test
```

> Three widget tests are `skip: true`: drift's stream-query store leaves a
> zero-duration timer on provider dispose, which flutter_test's fake-async
> clock reports as a pending timer. The behavior they cover is tested at the
> provider/DAO level instead.

## What it does

**Dashboard (`/`)**
- Task lists and notes shown as color-tinted cards in a two-column grid
- Long-press drag to reorder cards; swipe a card to move it to the trash
  (with Undo)
- Trash FAB with a live count; app bar: new list, new note, theme cycle

**Task lists (`/list/:id`)**
- Add (input on top, so the keyboard never covers it), rename by tap,
  complete, swipe-delete tasks; drag-handle reorder
- Filter by all / active / done, clear completed in one click
- Per-list color (8-color palette or custom picker), tinted across cards and
  views

**Notes (`/note/:id`)**
- Rich text editing with flutter_quill: headings, bold, italic, underline,
  font size, lists, link, quote, colors
- Compact one-row toolbar for the essentials; the chevron opens the full
  toolbar in a bottom sheet
- Auto-save (300 ms debounce + flush on back), editable title, per-note color,
  plain-text preview on the dashboard card

**Trash (`/trash`)**
- Holds deleted lists, notes and tasks for 30 days with a per-item countdown;
  expired items are purged on app start
- Restore, permanently delete (confirmed), or empty the whole trash

**Theming**
- Material 3, seeded color scheme, Inter typography, 20 px rounded cards
- Light / dark / system, persisted in shared_preferences

## Storage

All data lives in SQLite through drift (`lib/core/db/`) — tables for
`task_lists`, `todos`, `notes` and one merged `trash_items` table. Deleting a
list snapshots it *and* its tasks as a JSON payload into the trash; the list
row is removed and foreign keys cascade. Restoring replays that snapshot.
Times are epoch milliseconds, colors are nullable ARGB ints, card order is a
plain `position` column rewritten in a transaction on every drop.

UI state is never a second source of truth: drift query streams feed Riverpod
`StreamProvider`s, and every write goes through an action class
(`TaskListActions`, `NoteActions`, `TrashActions`, `DashboardActions`) that
runs inside a DAO transaction.

## Project structure

```
lib/
├── main.dart            # bootstrap: prefs, db, startup trash purge
├── app/                 # MaterialApp.router, GoRouter routes
│   ├── providers.dart   # appDatabase / sharedPreferences overrides
│   └── theme/           # M3 themes, ARGB tint helpers, 8-color palette
├── core/
│   ├── db/              # drift tables + AppDatabase + 4 DAOs + migrations
│   ├── utils/           # uuid, Debouncer, delta→plain-text, retention days
│   └── widgets/         # EmptyState, color picker sheet, undo snackbars
└── features/
    ├── dashboard/       # merged card feed, reorder, swipe-to-trash, FAB
    ├── task_list/       # list detail: add/rename/toggle/reorder/filter
    ├── notes/           # flutter_quill editor, autosave, colors
    ├── trash/           # restore / delete forever / empty / retention
    └── settings/        # persisted ThemeMode cycling
```

Docs: spec in `docs/superpowers/specs/`, implementation plan in
`docs/superpowers/plans/`.
