import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/app/theme/app_theme.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/core/widgets/color_picker_sheet.dart';
import 'package:todo_app_flutterv2/core/widgets/empty_state.dart';
import 'package:todo_app_flutterv2/core/widgets/undo_snack.dart';
import 'package:todo_app_flutterv2/features/task_list/providers.dart';
import 'package:todo_app_flutterv2/features/task_list/task_tile.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({required this.listId, super.key});

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

  Future<String?> _promptTitle({
    required String title,
    required String initial,
  }) {
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameList(TaskListRow list) async {
    final newTitle = await _promptTitle(
      title: 'Rename list',
      initial: list.title,
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await ref
          .read(taskListActionsProvider)
          .renameList(listId: list.id, title: newTitle);
    }
  }

  Future<void> _renameTask(TodoRow task) async {
    final newTitle = await _promptTitle(
      title: 'Rename task',
      initial: task.title,
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await ref
          .read(taskListActionsProvider)
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
    final db = ref.read(appDatabaseProvider);
    final trashId = await ref.read(taskListActionsProvider).moveListToTrash(
      list.id,
    );
    if (!mounted) return;
    context.pop();
    showUndoTrashSnack(
      context,
      db,
      trashId,
      'List moved to trash',
    );
  }

  Future<void> _submitTask() async {
    final title = _addController.text.trim();
    if (title.isEmpty) return;
    _addController.clear();
    await ref
        .read(taskListActionsProvider)
        .addTask(listId: widget.listId, title: title);
  }

  Widget _taskView(
    TaskListRow list,
    List<TodoRow> visible,
    bool reorderable,
    AppDatabase db,
  ) {
    Widget tile(BuildContext context, int index) {
      final task = visible[index];
      return Padding(
        key: ValueKey('task-${task.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Card(
          child: TaskTile(
            task: task,
            onToggle: () => ref.read(taskListActionsProvider).toggle(task),
            onRename: () => _renameTask(task),
            onDelete: () async {
              final trashId = await ref
                  .read(taskListActionsProvider)
                  .moveTaskToTrash(task);
              if (!context.mounted) return;
              showUndoTrashSnack(
                context,
                db,
                trashId,
                'Task moved to trash',
              );
            },
            dragHandle: reorderable
                ? ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  )
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
            .read(taskListActionsProvider)
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
    final listAsync = ref.watch(taskListProvider(widget.listId));
    final tasksAsync = ref.watch(todosOfListProvider(widget.listId));
    final filter = ref.watch(taskFilterProvider(widget.listId));
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
                  context: context,
                  current: list.color,
                  onPicked: (c) => ref.read(taskListActionsProvider).setListColor(list.id, c),
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
              // Add-task row on top: the keyboard never covers the input.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitTask(),
                        decoration: const InputDecoration(
                          hintText: 'Add a task…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _submitTask,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
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
                        ButtonSegment(
                          value: TaskFilterKind.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: TaskFilterKind.active,
                          label: Text('Active'),
                        ),
                        ButtonSegment(
                          value: TaskFilterKind.done,
                          label: Text('Done'),
                        ),
                      ],
                      selected: {filter},
                      onSelectionChanged: (s) => ref
                          .read(taskFilterProvider(widget.listId).notifier)
                          .select(s.first),
                    ),
                    IconButton(
                      tooltip: 'Clear completed',
                      onPressed: done == 0
                          ? null
                          : () async {
                              final ids = await ref
                                  .read(taskListActionsProvider)
                                  .clearCompleted(list.id);
                              if (!context.mounted) return;
                              showUndoMultiSnack(
                                context,
                                db,
                                ids,
                                '${ids.length} completed task(s) moved to '
                                'trash',
                              );
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
                          TaskFilterKind.all =>
                            'No tasks yet. Add one above.',
                          TaskFilterKind.active =>
                            'Nothing active — all done!',
                          TaskFilterKind.done => 'No completed tasks yet.',
                        },
                      )
                    : _taskView(
                        list,
                        visible,
                        filter == TaskFilterKind.all,
                        db,
                      ),
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
