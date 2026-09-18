import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('avatar runtime html and bundle assets exist in bundle', () async {
    final html = await rootBundle.loadString('assets/avatar_runtime/index.html');
    expect(html.contains('oneworks-avatar-container'), isTrue);
    expect(html.contains('avatar_bundle.js'), isTrue);

    final js = await rootBundle.loadString('assets/avatar_runtime/avatar_bundle.js');
    expect(js.contains('AvatarBridge'), isTrue);
    expect(js.contains('setLookAt'), isTrue);
  });
}
