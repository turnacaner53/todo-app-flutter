import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/utils/debouncer.dart';

void main() {
  test('collapses rapid calls into one delayed action', () async {
    var calls = 0;
    final d = Debouncer(const Duration(milliseconds: 30), () => calls++);
    d();
    d();
    d();
    expect(calls, 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1);
    d.dispose();
  });

  test('flush runs pending action, dispose cancels', () async {
    var calls = 0;
    final d = Debouncer(const Duration(milliseconds: 30), () => calls++);
    d();
    expect(d.hasPending, isTrue);
    d.flush();
    expect(calls, 1);
    expect(d.hasPending, isFalse);
    d();
    d.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1);
  });
}
