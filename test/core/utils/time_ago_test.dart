import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/utils/time_ago.dart';

void main() {
  final now = DateTime(2026, 9, 1, 12);

  test('fresh trash item has full window', () {
    expect(trashDaysLeft(now.subtract(const Duration(hours: 3)), now: now), 30);
  });

  test('29.5 days old has 1 left, expired clamps to 0', () {
    expect(
      trashDaysLeft(now.subtract(const Duration(days: 29, hours: 12)), now: now),
      1,
    );
    expect(trashDaysLeft(now.subtract(const Duration(days: 31)), now: now), 0);
  });
}
