import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/app/theme/app_theme.dart';
import 'package:todo_app_flutterv2/core/utils/debouncer.dart';
import 'package:todo_app_flutterv2/core/widgets/color_picker_sheet.dart';
import 'package:todo_app_flutterv2/core/widgets/empty_state.dart';
import 'package:todo_app_flutterv2/core/widgets/undo_snack.dart';
import 'package:todo_app_flutterv2/features/notes/providers.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({required this.noteId, super.key});

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
    final row =
        await (db.select(db.notes)..where((t) => t.id.equals(widget.noteId)))
            .getSingleOrNull();
    if (row == null || !mounted) return;
    _titleController.text = row.title;
    final quill = QuillController(
      document: parseNoteDocument(row.content),
      selection: const TextSelection.collapsed(offset: 0),
    )..addListener(_onChanged);
    setState(() {
      _quill = quill;
      _loaded = true;
    });
  }

  void _onChanged() {
    _dirty = true;
    _debouncer?.call();
  }

  String get _contentJson =>
      _quill == null ? '[]' : jsonEncode(_quill!.document.toDelta().toJson());

  Future<void> _saveNow() async {
    if (!_dirty) return;
    _dirty = false;
    await ref.read(noteActionsProvider).save(
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

  Future<void> _moveToTrash() async {
    final db = ref.read(appDatabaseProvider);
    final trashId = await ref.read(noteActionsProvider).moveNoteToTrash(
      widget.noteId,
    );
    if (!mounted) return;
    context.pop();
    showUndoTrashSnack(
      context,
      db,
      trashId,
      'Note moved to trash',
    );
  }

  /// Full multi-row toolbar (undo/redo, lists, colors, link, quote, ...) in a
  /// bottom sheet, sharing the same controller as the compact row.
  Future<void> _showFullToolbarSheet() {
    final quill = _quill;
    if (quill == null) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'More formatting',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              QuillSimpleToolbar(controller: quill),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(noteProvider(widget.noteId));

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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
                icon: Icon(
                  Icons.palette,
                  color: row.color == null ? null : Color(row.color!),
                ),
                onPressed: () => showColorPickerSheet(
                  context: context,
                  current: row.color,
                  onPicked: (c) =>
                      ref.read(noteActionsProvider).setNoteColor(widget.noteId, c),
                ),
              ),
              IconButton(
                tooltip: 'Move to trash',
                icon: const Icon(Icons.delete_outline),
                onPressed: _moveToTrash,
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
                    _debouncer?.call();
                  },
                ),
              ),
              const Divider(height: 1),
              Row(
                children: [
                  Expanded(
                    child: QuillSimpleToolbar(
                      controller: _quill!,
                      config: const QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        showDividers: false,
                        toolbarIconAlignment: WrapAlignment.start,
                        // First row keeps the defaults: header, font-size,
                        // bold, italic, underline. Everything else lives in
                        // the expand sheet:
                        showUndo: false,
                        showRedo: false,
                        showFontFamily: false,
                        showStrikeThrough: false,
                        showInlineCode: false,
                        showColorButton: false,
                        showBackgroundColorButton: false,
                        showClearFormat: false,
                        showListNumbers: false,
                        showListBullets: false,
                        showListCheck: false,
                        showCodeBlock: false,
                        showQuote: false,
                        showIndent: false,
                        showLink: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More formatting',
                    icon: const Icon(Icons.expand_more),
                    onPressed: _showFullToolbarSheet,
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: QuillEditor.basic(controller: _quill!),
              ),
            ],
          ),
        );
      },
      orElse: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
