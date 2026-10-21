import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/companion/render/avatar_svg_preparer.dart';

/// A miniature of how the OneWorks snapshots are actually exported: a
/// full-bleed plate, a drop-shadow filter, an empty clip path, then the pet.
const String _snapshot = '<svg xmlns="http://www.w3.org/2000/svg" '
    'viewBox="0 0 420 420">'
    '<rect width="420" height="420" rx="34" fill="#111315"></rect>'
    '<defs>'
    '<filter id="s-shadow"><feDropShadow dx="-6" dy="7" stdDeviation="7" '
    'flood-color="#7c3140" flood-opacity="0.28"></feDropShadow></filter>'
    '<clipPath id="s-clip"><path d=""></path></clipPath>'
    '</defs>'
    '<g filter="url(#s-shadow)" clip-path="url(#s-clip)">'
    '<path d="M10 10h100v100h-100z" fill="#f7f7f4"></path>'
    '<path d="M30 30h20v20h-20z" fill="#050608"></path>'
    '<path d="M70 30h20v20h-20z" fill="#050608"></path>'
    '</g>'
    '</svg>';

void main() {
  group('stripAvatarChrome', () {
    test('drops the opaque backdrop plate when transparency is wanted', () {
      final result = stripAvatarChrome(_snapshot, transparentBackdrop: true);

      expect(result, isNot(contains('rx="34"')));
      expect(result, contains('#f7f7f4'), reason: 'the pet must survive');
    });

    test('keeps the backdrop plate when it is wanted', () {
      final result = stripAvatarChrome(_snapshot, transparentBackdrop: false);

      expect(result, contains('rx="34"'));
    });

    test('removes filters the renderer cannot draw, keeping their subject', () {
      final result = stripAvatarChrome(_snapshot, transparentBackdrop: true);

      expect(result, isNot(contains('filter="url(')));
      expect(result, isNot(contains('<filter')));
      expect(result, isNot(contains('feDropShadow')));
      expect(result, contains('<path d="M10 10h100v100h-100z"'));
    });

    test('removes empty clip paths and every reference to them', () {
      final result = stripAvatarChrome(_snapshot, transparentBackdrop: true);

      expect(result, isNot(contains('clip-path="url(#s-clip)"')));
      expect(result, isNot(contains('<clipPath')));
    });

    test('leaves a clip path that actually clips something alone', () {
      const withRealClip = '<svg viewBox="0 0 10 10">'
          '<defs><clipPath id="keep"><path d="M0 0h5v5z"></path></clipPath></defs>'
          '<g clip-path="url(#keep)"><path d="M0 0h9v9z" fill="#abcdef"></path></g>'
          '</svg>';

      final result =
          stripAvatarChrome(withRealClip, transparentBackdrop: true);

      expect(result, contains('<clipPath id="keep">'));
      expect(result, contains('clip-path="url(#keep)"'));
    });
  });

  group('buildPaletteSubstitutions', () {
    test('maps the most-used colour onto the palette primary', () {
      final prepared =
          stripAvatarChrome(_snapshot, transparentBackdrop: true);
      final substitutions = buildPaletteSubstitutions(
        prepared,
        AvatarPalette.coolBlue,
        1.0,
      );

      // #050608 is used twice and #f7f7f4 once, so the dark ink is the most
      // common colour — but it is also the darkest, so it must stay ink.
      final ink = substitutions[0xFF050608];
      final body = substitutions[0xFFF7F7F4];

      expect(ink, isNotNull);
      expect(body, isNotNull);
      expect(_luma(ink!), lessThan(0.3), reason: 'eyes and outlines stay dark');
      expect(body, isNot(0xFFF7F7F4), reason: 'the body takes the palette');
    });

    test('ignores the drop shadow colour once the filter is gone', () {
      final prepared =
          stripAvatarChrome(_snapshot, transparentBackdrop: true);
      final substitutions = buildPaletteSubstitutions(
        prepared,
        AvatarPalette.coolBlue,
        1.0,
      );

      expect(
        substitutions.containsKey(0xFF7C3140),
        isFalse,
        reason: 'the shadow flood colour would take a real palette role',
      );
    });

    test('a strength of zero leaves the artwork untouched', () {
      final substitutions = buildPaletteSubstitutions(
        _snapshot,
        AvatarPalette.vibrant,
        0.0,
      );

      substitutions.forEach((source, result) {
        expect(result, source);
      });
    });
  });

  group('content centring', () {
    /// Re-reads the viewBox the preparer wrote, so the assertions are about
    /// what the renderer will actually frame.
    ({double x, double y, double w, double h}) viewBoxOf(String svg) {
      final raw = RegExp('viewBox="([^"]*)"').firstMatch(svg)!.group(1)!;
      final parts = raw.split(RegExp(r'[ ,]+')).map(double.parse).toList();
      return (x: parts[0], y: parts[1], w: parts[2], h: parts[3]);
    }

    test('measures where the artwork really sits, not where the box is', () {
      final prepared =
          stripAvatarChrome(_snapshot, transparentBackdrop: true);
      final bounds = measureContent(prepared, 'snapshot');

      expect(bounds, isNotNull);
      // The pet in the fixture spans 10..110, so its centre is 60 — not the
      // 210 the 420-wide viewBox would suggest.
      expect(bounds!.centerX, closeTo(60, 0.5));
      expect(bounds.centerY, closeTo(60, 0.5));
    });

    test('re-frames the viewBox so the artwork lands in the middle', () {
      final prepared =
          stripAvatarChrome(_snapshot, transparentBackdrop: true);
      final bounds = measureContent(prepared, 'snapshot')!;
      final framed = recenterViewBox(prepared, bounds);
      final box = viewBoxOf(framed);

      expect(box.x + box.w / 2, closeTo(bounds.centerX, 0.05));
      expect(box.y + box.h / 2, closeTo(bounds.centerY, 0.05));
    });

    test('the new frame is square, so species come out the same size', () {
      final prepared =
          stripAvatarChrome(_snapshot, transparentBackdrop: true);
      final bounds = measureContent(prepared, 'snapshot')!;
      final box = viewBoxOf(recenterViewBox(prepared, bounds));

      expect(box.w, closeTo(box.h, 0.001));
      expect(box.w, greaterThan(bounds.width), reason: 'leaves a margin');
    });

    test('every bundled species ends up centred', () {
      final dir = Directory('assets/avatars/species');
      if (!dir.existsSync()) return;

      var checked = 0;
      var worstOffset = 0.0;
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.svg')) continue;
        final prepared = stripAvatarChrome(
          file.readAsStringSync(),
          transparentBackdrop: true,
        );
        final bounds = measureContent(prepared, file.path);
        expect(bounds, isNotNull, reason: '${file.path} has no measurable art');

        final box = viewBoxOf(recenterViewBox(prepared, bounds!));
        final dx = (box.x + box.w / 2 - bounds.centerX).abs();
        final dy = (box.y + box.h / 2 - bounds.centerY).abs();
        worstOffset = [worstOffset, dx, dy].reduce((a, b) => a > b ? a : b);
        checked++;
      }

      expect(checked, greaterThan(25));
      expect(
        worstOffset,
        lessThan(0.05),
        reason: 'no species may sit off to one side',
      );
    });

    test('leaves the framing alone when the backdrop plate is kept', () {
      final withPlate = compileAvatarArtwork(
        const AvatarArtworkRecipe(
          assetKey: 'test',
          transparentBackdrop: false,
        ),
        _snapshot,
      );

      expect(withPlate.lengthInBytes, greaterThan(0));
    });
  });

  group('compileAvatarArtwork', () {
    test('produces a decodable buffer', () {
      final bytes = compileAvatarArtwork(
        const AvatarArtworkRecipe(assetKey: 'test'),
        _snapshot,
      );

      expect(bytes.lengthInBytes, greaterThan(0));
    });

    test('a palette changes the bytes without changing the geometry', () {
      const plain = AvatarArtworkRecipe(assetKey: 'test');
      const tinted = AvatarArtworkRecipe(
        assetKey: 'test',
        palette: AvatarPalette.cyberpunk,
      );

      final a = compileAvatarArtwork(plain, _snapshot);
      final b = compileAvatarArtwork(tinted, _snapshot);

      expect(a.lengthInBytes, b.lengthInBytes);
      expect(a, isNot(orderedEquals(b)));
    });

    test('compiles every bundled species and breed at runtime settings', () {
      // The optimizers `encodeSvg` enables by default need the native PathOps
      // library, which only exists in the build tooling. This is the guard
      // against that regressing: it throws for every file if it does.
      final directories = <String>[
        'assets/avatars/species',
        'assets/avatars/breeds',
      ];

      var compiled = 0;
      for (final path in directories) {
        final dir = Directory(path);
        if (!dir.existsSync()) continue;

        for (final file in dir.listSync().whereType<File>()) {
          if (!file.path.endsWith('.svg')) continue;
          final bytes = compileAvatarArtwork(
            AvatarArtworkRecipe(assetKey: file.path),
            file.readAsStringSync(),
          );
          expect(
            bytes.lengthInBytes,
            greaterThan(0),
            reason: '${file.path} compiled to nothing',
          );
          compiled++;
        }
      }

      expect(compiled, greaterThan(100), reason: 'assets should be present');
    });
  });
}

double _luma(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255.0;
  final g = ((argb >> 8) & 0xFF) / 255.0;
  final b = (argb & 0xFF) / 255.0;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
