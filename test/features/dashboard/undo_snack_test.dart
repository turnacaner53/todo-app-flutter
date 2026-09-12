import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/core/widgets/undo_snack.dart';

/// Regression: since Flutter 3.41, a SnackBar with an action defaults to
/// `persist: true` and never auto-dismisses. Our undo snackbars must
/// disappear after ~5 seconds (spec: trash actions show a transient Undo).
void main() {
  testWidgets('trash snackbar auto-dismisses after 5s', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showUndoTrashSnack(
                  context,
                  db,
                  'trash-1',
                  'Note moved to trash',
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump(); // start entrance animation
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Note moved to trash'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Note moved to trash'), findsNothing);
  });
}
