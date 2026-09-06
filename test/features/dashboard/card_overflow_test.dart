import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/features/dashboard/dashboard_screen.dart';

/// Regression: dashboard list cards used to log "BOTTOM OVERFLOWED" once the
/// preview (2 tasks + "and N more" + footer) exceeded the fixed card height,
/// especially at large OS text scales. The preview now lives in a
/// shrinkWrap/never-scroll viewport.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('full list card does not overflow at 1.5x text scale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final id = await db.taskListDao.create('Shopping list');
    for (final t in ['ssud', 'rjfvcvg', 'djdiffg', 'bir uzun görev daha']) {
      await db.todoDao.add(id, t);
    }

    tester.view.devicePixelRatio = 2.75;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.5,
            maxScaleFactor: 1.5,
            child: child!,
          ),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
  });
}
