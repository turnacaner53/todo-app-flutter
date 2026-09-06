import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app_flutterv2/core/db/database.dart';

/// Single app-wide database. Override with AppDatabase(NativeDatabase.memory())
/// in tests.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('overridden in main'),
);

/// SharedPreferences instance obtained before runApp; overridden in main.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('override sharedPreferencesProvider in main()'),
);
