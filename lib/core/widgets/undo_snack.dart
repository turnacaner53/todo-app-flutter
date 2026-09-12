import 'package:flutter/material.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

/// SnackBar with Undo that restores [trashId] from the trash.
void showUndoTrashSnack(
  BuildContext context,
  AppDatabase db,
  String trashId,
  String message,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        // Flutter 3.41 makes snackbars with an action persistent by default;
        // undo snackbars must auto-dismiss after 5s.
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => db.trashDao.restore(trashId),
        ),
      ),
    );
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
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        // See showUndoTrashSnack: action snackbars persist by default.
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            for (final id in trashIds) {
              await db.trashDao.restore(id);
            }
          },
        ),
      ),
    );
}
