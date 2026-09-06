import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:todo_app_flutterv2/app/theme/palette.dart';

/// Bottom sheet: 8-swatch palette (+clear +custom) with apply callback.
Future<void> showColorPickerSheet({
  required BuildContext context,
  required Future<void> Function(int? color) onPicked,
  int? current,
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
                        builder: (context) =>
                            _CustomColorDialog(initial: selected),
                      );
                      if (custom != null) {
                        setSheetState(() => selected = custom);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () {
                    unawaited(onPicked(selected));
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
          color:
              icon != null
                  ? scheme.surfaceContainerHighest
                  : color == null
                  ? scheme.surfaceContainerHighest
                  : Color(color!),
          border: selected
              ? Border.all(color: scheme.onSurface, width: 2.5)
              : Border.all(color: scheme.outlineVariant),
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
  late Color _color =
      widget.initial == null ? const Color(0xFF3B82F6) : Color(widget.initial!);

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
