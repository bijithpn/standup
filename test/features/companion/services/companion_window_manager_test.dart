import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompanionWindowManager sizing constraints', () {
    test('enforces strict min and max bounds for PiP window', () {
      expect(CompanionWindowManager.minSize, const Size(180, 210));
      expect(CompanionWindowManager.maxSize, const Size(360, 420));
      expect(CompanionWindowManager.defaultSize, const Size(280, 320));
    });
  });
}
