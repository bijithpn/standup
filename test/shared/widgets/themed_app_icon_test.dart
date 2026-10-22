import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:breakmate/shared/widgets/themed_app_icon.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/themes/domain/app_theme_preset.dart';

void main() {
  group('ThemedAppIcon', () {
    testWidgets(
      'renders SvgPicture with active theme accent color by default',
      (tester) async {
        AppTheme.applyPreset(AppThemePreset.nordicSlate);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ThemedAppIcon(size: 64))),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ThemedAppIcon), findsOneWidget);
        expect(find.byType(SvgPicture), findsOneWidget);
      },
    );

    testWidgets('generates SVG string containing correct hex color', (
      tester,
    ) async {
      const testColor = Color(0xFF38BDF8);
      final svgStr = ThemedAppIcon.generateSvgString(color: testColor);

      expect(svgStr, contains('#38bdf8'));
      expect(svgStr, contains(ThemedAppIcon.rightGlyphPath));
      expect(svgStr, contains(ThemedAppIcon.leftGlyphPath));
    });

    testWidgets('supports custom color override', (tester) async {
      const customColor = Color(0xFFFF5722);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ThemedAppIcon(size: 48, color: customColor)),
        ),
      );
      await tester.pumpAndSettle();

      final themedIcon = tester.widget<ThemedAppIcon>(
        find.byType(ThemedAppIcon),
      );
      expect(themedIcon.color, equals(customColor));
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders in badge mode with styled container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ThemedAppIcon.badge(size: 72))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ThemedAppIcon), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    });
  });
}
