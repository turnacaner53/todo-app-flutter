import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app_flutterv2/app/providers.dart';

const _key = 'theme_mode';

ThemeMode _readMode(SharedPreferences prefs) {
  final raw = prefs.getString(_key);
  return ThemeMode.values.firstWhere(
    (m) => m.name == raw,
    orElse: () => ThemeMode.system,
  );
}

/// Light/dark/system preference, persisted to SharedPreferences.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => _readMode(ref.watch(sharedPreferencesProvider));

  void setMode(ThemeMode mode) {
    state = mode;
    unawaited(ref.read(sharedPreferencesProvider).setString(_key, mode.name));
  }

  void cycle() =>
      setMode(ThemeMode.values[(state.index + 1) % ThemeMode.values.length]);
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
