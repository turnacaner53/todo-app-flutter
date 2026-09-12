import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app_flutterv2/app/theme/app_theme.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/core/utils/delta_text.dart';
import 'package:todo_app_flutterv2/features/dashboard/providers.dart';
import 'package:todo_app_flutterv2/features/task_list/providers.dart';

/// Masonry cards size themselves to their content: an empty card is the
/// smallest, and long content is capped at [maxPreviewLines] lines before an
/// "and N more…" row.
const maxPreviewLines = 6;

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

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
    final pending = tasks.where((t) => !t.completed).toList();
    final preview = pending.take(maxPreviewLines).toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardHeader(
          icon: Icons.checklist_rounded,
          color: argbToColor(row.color) ?? scheme.primary,
          title: row.title,
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Text('No tasks yet', style: Theme.of(context).textTheme.bodySmall)
        else ...[
          for (final t in preview)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_unchecked, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (pending.length > maxPreviewLines)
            Text(
              'and ${pending.length - maxPreviewLines} more…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        const SizedBox(height: 10),
        Text(
          '${pending.length} to do',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardHeader(
          icon: Icons.sticky_note_2_rounded,
          color: argbToColor(row.color) ?? scheme.primary,
          title: row.title.isEmpty ? 'Untitled' : row.title,
        ),
        const SizedBox(height: 8),
        Text(
          preview.isEmpty ? 'Empty note' : preview,
          maxLines: maxPreviewLines,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
