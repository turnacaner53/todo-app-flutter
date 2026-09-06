import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_flutterv2/core/utils/delta_text.dart';

void main() {
  test('concatenates string inserts and trims trailing newline', () {
    const delta =
        r'{"ops":[{"insert":"Hello "},{"insert":"world","attributes":{"bold":true}},{"insert":"\n"}]}';
    expect(deltaToPlainText(delta), 'Hello world');
  });

  test('supports bare op list format', () {
    const delta = r'[{"insert":"One"},{"insert":"\nTwo"}]';
    expect(deltaToPlainText(delta), 'One\nTwo');
  });

  test('embeds are skipped, empty input safe', () {
    const delta = '{"ops":[{"insert":{"image":"x"}},{"insert":"pic"}]}';
    expect(deltaToPlainText(delta), 'pic');
    expect(deltaToPlainText(''), '');
  });
}
