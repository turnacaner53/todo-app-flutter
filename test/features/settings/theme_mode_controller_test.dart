import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app_flutterv2/app/providers.dart';
import 'package:todo_app_flutterv2/features/settings/theme_mode_controller.dart';

void main() {
  Future<ProviderContainer> containerWith(String? storedMode) async {
    SharedPreferences.setMockInitialValues(
      storedMode == null ? {} : {'theme_mode': storedMode},
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to system, persists, reads back', () async {
    final c = await containerWith(null);
    expect(c.read(themeModeControllerProvider), ThemeMode.system);

    c.read(themeModeControllerProvider.notifier).setMode(ThemeMode.dark);
    expect(c.read(themeModeControllerProvider), ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getString('theme_mode'),
        'dark');

    final c2 = await containerWith('dark');
    expect(c2.read(themeModeControllerProvider), ThemeMode.dark);
  });

  test('cycle walks system → light → dark → system', () async {
    final c = await containerWith(null);
    final notifier = c.read(themeModeControllerProvider.notifier);
    const expected = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
    for (final mode in expected) {
      notifier.cycle();
      expect(c.read(themeModeControllerProvider), mode);
    }
  });
}
