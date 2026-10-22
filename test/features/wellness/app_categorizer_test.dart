import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  group('AppCategorizer', () {
    test('categorizes coding apps', () {
      expect(
        AppCategorizer.categorize(name: 'Visual Studio Code', bundleId: 'com.microsoft.vscode'),
        AppCategory.coding,
      );
      expect(
        AppCategorizer.categorize(name: 'Xcode', bundleId: 'com.apple.dt.xcode'),
        AppCategory.coding,
      );
    });

    test('categorizes writing apps', () {
      expect(
        AppCategorizer.categorize(name: 'Notes', bundleId: 'com.apple.notes'),
        AppCategory.writing,
      );
    });

    test('categorizes browsers', () {
      expect(
        AppCategorizer.categorize(name: 'Google Chrome', bundleId: 'com.google.chrome'),
        AppCategory.browsing,
      );
    });

    test('categorizes meeting apps', () {
      expect(
        AppCategorizer.categorize(name: 'Zoom', bundleId: 'us.zoom.xos'),
        AppCategory.meeting,
      );
    });

    test('categorizes design apps', () {
      expect(
        AppCategorizer.categorize(name: 'Figma', bundleId: 'com.figma.desktop'),
        AppCategory.design,
      );
    });

    test('falls back to general for unmatched apps', () {
      expect(
        AppCategorizer.categorize(name: 'Calculator', bundleId: 'com.apple.calculator'),
        AppCategory.general,
      );
    });
  });
}
