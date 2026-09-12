import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/widgets/empty_state.dart';
import 'package:todo_app_flutterv2/core/widgets/undo_snack.dart';
import 'package:todo_app_flutterv2/features/dashboard/dash_card.dart';
import 'package:todo_app_flutterv2/features/dashboard/providers.dart';
import 'package:todo_app_flutterv2/features/settings/theme_mode_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Startup retention purge runs in main()'s bootstrap (spec §7).

  Future<void> _openNewList() async {
    final id = await ref.read(dashboardActionsProvider).createList();
    if (mounted) unawaited(context.push('/list/$id'));
  }

  Future<void> _openNewNote() async {
    final id = await ref.read(dashboardActionsProvider).createNote();
    if (mounted) unawaited(context.push('/note/$id'));
  }

  /// FAB handler: choose between creating a new task list or a new note,
  /// presented as two full-width pill buttons, not a plain list drawer.
  Future<void> _showCreateSheet() {
    final scheme = Theme.of(context).colorScheme;
    Future<void> pick(void Function() action) async {
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      action();
    }

    Widget button({
      required IconData icon,
      required String label,
      required bool filled,
      required VoidCallback onTap,
    }) {
      final style = filled
          ? FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            )
          : FilledButton.styleFrom(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
            );
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          style: style,
          onPressed: onTap,
          icon: Icon(icon, size: 22),
          label: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              button(
                icon: Icons.playlist_add,
                label: 'New task list',
                filled: true,
                onTap: () => pick(() => unawaited(_openNewList())),
              ),
              const SizedBox(height: 12),
              button(
                icon: Icons.note_add_outlined,
                label: 'New note',
                filled: false,
                onTap: () => pick(() => unawaited(_openNewNote())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(dashFeedProvider);
    final trash = ref.watch(trashCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos'),
        actions: [
          IconButton(
            tooltip: 'Trash',
            icon: Badge(
              isLabelVisible: trash > 0,
              label: Text('$trash'),
              child: const Icon(Icons.delete_outline),
            ),
            onPressed: () => context.push('/trash'),
          ),
          IconButton(
            tooltip: 'Theme',
            icon: Icon(
              switch (Theme.of(context).brightness) {
                Brightness.dark => Icons.dark_mode_outlined,
                Brightness.light => Icons.light_mode_outlined,
              },
            ),
            onPressed: () =>
                ref.read(themeModeControllerProvider.notifier).cycle(),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          heroTag: 'add-fab',
          onPressed: _showCreateSheet,
          child: const Icon(Icons.add),
        ),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.dashboard_customize_outlined,
              message: 'Nothing here yet.',
              actionLabel: 'Create your first list',
              onAction: _openNewList,
            )
          : ReorderableBuilder<Widget>(
              children: [
                for (final item in items)
                  DashCard(
                    key: ValueKey('card-${item.id}'),
                    item: item,
                    onDismiss: () async {
                      final db = ref.read(appDatabaseProvider);
                      final trashId = await ref
                          .read(dashboardActionsProvider)
                          .moveToTrash(item);
                      if (!context.mounted) return;
                      showUndoTrashSnack(
                        context,
                        db,
                        trashId,
                        'Moved to trash',
                      );
                    },
                  ),
              ],
              onReorderPositions: (updates) async {
                final ordered = [...items];
                for (final u in updates) {
                  ordered.insert(u.newIndex, ordered.removeAt(u.oldIndex));
                }
                await ref.read(dashboardActionsProvider).reorder(ordered);
              },
              builder: (children) => MasonryGridView.count(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemCount: children.length,
                itemBuilder: (context, index) => children[index],
              ),
            ),
    );
  }
}
