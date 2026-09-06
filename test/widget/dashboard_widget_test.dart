import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/app/theme/app_theme.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';
import 'package:todo_app_flutterv2/features/dashboard/dashboard_screen.dart';

// NOT: drift StreamProvider dispose'ta fake-async clock'ta bekleyen
// zamanlayıcı bırakıyor; pumpAndSettle sonsuza kadar bekliyor (aynı sorun
// smoke_test'te, o yüzden orada skip). Davranışsal kapsam provider seviyesi
// dash_feed_test + DAO testlerinde; bu widget testleri emülatör akışıyla
// doğrulanıyor.
Future<void> pumpDashboard(WidgetTester tester, AppDatabase db) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const DashboardScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'shows empty state when no content',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await pumpDashboard(tester, db);

      expect(find.text('Nothing here yet.'), findsOneWidget);
      expect(find.text('Create your first list'), findsOneWidget);
    },
    skip: true,
  );

  testWidgets(
    'renders a list card with task preview',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.taskListDao.create('Groceries');
      await db.todoDao.add(id, 'Milk');
      await db.todoDao.add(id, 'Eggs');
      await pumpDashboard(tester, db);

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('2 to do'), findsOneWidget);
    },
    skip: true,
  );
}
