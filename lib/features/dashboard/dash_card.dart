import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app_flutterv2/app/theme/app_theme.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/core/utils/delta_text.dart';
import 'package:todo_app_flutterv2/features/dashboard/providers.dart';
import 'package:todo_app_flutterv2/features/task_list/providers.dart';

class DashCard extends StatelessWidget {
  const DashCard({
    required this.item,
    required this.onDismiss,
    super.key,
  });

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
          onTap: () => context.push(
            item.isList ? '/list/${item.id}' : '/note/${item.id}',
          ),
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
    final tasks =
        ref.watch(todosOfListProvider(row.id)).value ?? const <TodoRow>[];
    const maxPreview = 2;
    final preview = tasks.where((t) => !t.completed).take(maxPreview).toList();
    final remaining = tasks.where((t) => !t.completed).length;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 18,
              color: argbToColor(row.color) ?? scheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                row.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          // Non-scrollable shrinkWrap viewport: preview rows that don't fit
          // are simply not painted — no RenderFlex overflow at large text
          // scales.
          child: tasks.isEmpty
              ? Text(
                  'No tasks yet',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    for (final t in preview)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_unchecked, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (remaining > maxPreview)
                      Text(
                        'and ${remaining - maxPreview} more…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
        ),
        Text(
          '$remaining to do',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
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
            Icon(
              Icons.sticky_note_2_rounded,
              size: 18,
              color: argbToColor(row.color) ??
                  Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                row.title.isEmpty ? 'Untitled' : row.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Text(
                preview.isEmpty ? 'Empty note' : preview,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
