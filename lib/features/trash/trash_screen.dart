import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/core/utils/time_ago.dart';
import 'package:todo_app_flutterv2/core/widgets/empty_state.dart';
import 'package:todo_app_flutterv2/features/trash/providers.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(trashActionsProvider).purgeExpired());
  }

  Future<bool> _confirm(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(trashFeedProvider).value ??
        const <TrashItemRow>[];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                if (!await _confirm('Empty the trash?')) return;
                await ref.read(trashActionsProvider).emptyAll();
              },
              child: const Text('Empty'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.delete_outline_rounded,
              message:
                  'Trash is empty.\nDeleted items stay here for 30 days.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      switch (row.kind) {
                        'list' => Icons.checklist_rounded,
                        'note' => Icons.sticky_note_2_rounded,
                        _ => Icons.check_circle_outline,
                      },
                      color: scheme.primary,
                    ),
                    title: Text(
                      trashItemTitle(row),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${trashItemLabel(row)} · '
                      '${trashDaysLeft(row.deletedAt)} days left',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Restore',
                          icon: const Icon(Icons.undo),
                          onPressed: () =>
                              ref.read(trashActionsProvider).restore(row.id),
                        ),
                        IconButton(
                          tooltip: 'Delete forever',
                          icon: Icon(
                            Icons.delete_forever_outlined,
                            color: scheme.error,
                          ),
                          onPressed: () async {
                            if (!await _confirm(
                              'Delete "${trashItemTitle(row)}" forever?',
                            )) {
                              return;
                            }
                            await ref
                                .read(trashActionsProvider)
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
