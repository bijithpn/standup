import 'dart:math' as math;

import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

/// WCAG contrast of [fg] over an opaque [bg].
double contrast(Color fg, Color bg) {
  final over = Color.alphaBlend(fg, bg);
  final a = _lum(over), b = _lum(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  group('palette contrast (WCAG AA)', () {
    for (final entry in {
      'dark': BreakPalette.dark,
      'light': BreakPalette.light,
    }.entries) {
      final p = entry.value;
      for (final bg in {
        'canvas': p.canvas,
        'canvasRaised': p.canvasRaised,
      }.entries) {
        test('${entry.key}: body text on ${bg.key}', () {
          expect(
            contrast(p.textSecondary, bg.value),
            greaterThanOrEqualTo(4.5),
          );
          expect(contrast(p.textMuted, bg.value), greaterThanOrEqualTo(4.5));
        });
        test('${entry.key}: countdown on ${bg.key} (large text, 3:1)', () {
          expect(contrast(p.textPrimary, bg.value), greaterThanOrEqualTo(3.0));
        });
      }
    }
  });

  test('accentOn leaves dark accents alone and deepens light ones', () {
    const a = BreakOverlayTheme.eyeRest;
    expect(BreakPalette.dark.accentOn(a), a);
    expect(
      contrast(BreakPalette.light.accentOn(a), BreakPalette.light.canvas),
      greaterThan(contrast(a, BreakPalette.light.canvas)),
    );
  });

  group('overlay window defaults', () {
    setUpAll(setUpBreakTestEnvironment);

    // The standalone overlay is a bare MaterialApp, whose default ThemeData is
    // light. Break screens must stay dark there.
    testWidgets('stay dark under a default (light) MaterialApp theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext inner;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(Theme.of(inner).brightness, Brightness.light);
      expect(BreakPalette.of(inner), BreakPalette.dark);
    });

    testWidgets('a BreakPaletteScope opts a subtree into light', (
      tester,
    ) async {
      late BuildContext inner;
      await tester.pumpWidget(
        MaterialApp(
          home: BreakPaletteScope(
            palette: BreakPalette.light,
            child: Builder(
              builder: (context) {
                inner = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(BreakPalette.of(inner), BreakPalette.light);
    });
  });
}
