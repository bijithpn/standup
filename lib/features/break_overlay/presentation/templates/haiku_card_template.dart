import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class HaikuCardTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const HaikuCardTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  static const _haikus = [
    ['Eyes need distance,', 'the horizon waits —', 'let the screen dissolve.'],
    [
      'Shoulders drop. Breath slows.',
      'This moment is the only',
      'one that will ever be.',
    ],
    [
      'Step back from the glass.',
      'The world exists beyond it,',
      'wide and unhurried.',
    ],
    [
      'Blink. The tension fades.',
      'Your eyes have earned this rest —',
      'give them the far field.',
    ],
  ];

  @override
  State<HaikuCardTemplate> createState() => _HaikuCardTemplateState();
}

class _HaikuCardTemplateState extends State<HaikuCardTemplate> {
  /// Fixed for the whole break so the poem does not change when the minute
  /// rolls over.
  late final List<String> _poem =
      HaikuCardTemplate._haikus[clock.now().minute % 4];
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);
  final _MountainCache _mountains = _MountainCache();

  @override
  void initState() {
    super.initState();
    if (_Grain.tile == null) {
      _Grain.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      breakTimeTinted(breakAccent(widget.settings, 'haiku_card', _kind.accent)),
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final reduced = BreakMotion.reduced(context);
    final ink = palette.isDark ? Colors.white : const Color(0xFF1C1F24);
    final cardFill = palette.isDark
        ? const Color(0xFFF5F0E6).withValues(alpha: 0.06)
        : Colors.white;
    final cardBorder = palette.isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFF1C1F24).withValues(alpha: 0.10);

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: Stack(
        fit: StackFit.expand,
        children: [
          BreakSmoothProgress(
            progress: progress,
            builder: (context, anim) => CustomPaint(
              painter: _MountainPainter(
                cache: _mountains,
                progress: reduced ? null : anim,
                color: ink,
              ),
            ),
          ),
          if (_Grain.tile != null)
            IgnorePointer(
              child: CustomPaint(painter: _GrainPainter(tint: ink)),
            ),
        ],
      ),
      child: Center(
        child: AnimatedOpacity(
          // Completion: the card fades.
          opacity: complete ? 0 : 1,
          duration: BreakMotion.slow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BreakEntrance(
                scale: false,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: cardFill,
                    borderRadius: BorderRadius.circular(
                      BreakOverlayTheme.radiusLg,
                    ),
                    border: Border.all(color: cardBorder),
                    boxShadow: palette.isDark
                        ? null
                        : BreakOverlayTheme.surfaceShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Badge(_kind.label, palette),
                          const SizedBox(width: 8),
                          _Badge(
                            breakDurationLabel(widget.totalSeconds),
                            palette,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // The poem is read as a single block.
                      Semantics(
                        container: true,
                        label: _poem.join(' '),
                        excludeSemantics: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < _poem.length; i++)
                              BreakEntrance(
                                delay: Duration(milliseconds: 400 * i),
                                scale: false,
                                duration: const Duration(milliseconds: 700),
                                child: Text(
                                  _poem[i],
                                  textAlign: TextAlign.center,
                                  style: BreakOverlayTheme.serif.copyWith(
                                    fontSize: 22,
                                    fontStyle: FontStyle.italic,
                                    height: 1.8,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              BreakEntrance(
                delay: BreakEntrance.stagger(2),
                scale: false,
                child: BreakProgressRing(
                  size: 64,
                  strokeWidth: 2,
                  progress: progress,
                  color: accent,
                  trackColor: palette.track,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    style: BreakOverlayTheme.body.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.0,
                      fontFeatures: BreakOverlayTheme.tabular,
                    ),
                    color: breakClockColor(widget.settings, palette),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final BreakPalette palette;

  const _Badge(this.text, this.palette);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text.toUpperCase(),
        style: BreakOverlayTheme.micro.copyWith(color: palette.textMuted),
      ),
    );
  }
}

class _MountainCache {
  Size? size;
  final List<Path> paths = [];

  void build(Size s) {
    if (size == s) return;
    size = s;
    paths.clear();
    // Three overlapping ridgelines in the lower third.
    const ridges = [
      (base: 0.74, amp: 0.07, seed: 3.0),
      (base: 0.82, amp: 0.09, seed: 7.0),
      (base: 0.90, amp: 0.06, seed: 11.0),
    ];
    for (final r in ridges) {
      final path = Path()..moveTo(-20, s.height);
      for (var i = 0; i <= 48; i++) {
        final t = i / 48;
        final x = -20 + (s.width + 40) * t;
        final y =
            s.height *
            (r.base -
                r.amp *
                    (0.5 +
                        0.5 *
                            (math.sin(t * 5.1 + r.seed) *
                                    math.cos(t * 2.3 + r.seed * 0.7))
                                .abs()));
        path.lineTo(x, y);
      }
      path
        ..lineTo(s.width + 20, s.height)
        ..close();
      paths.add(path);
    }
  }
}

class _MountainPainter extends CustomPainter {
  final _MountainCache cache;
  final Animation<double>? progress;
  final Color color;

  static const _alphas = [0.04, 0.055, 0.07];
  final Paint _p = Paint();

  _MountainPainter({
    required this.cache,
    required this.progress,
    required this.color,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    cache.build(size);
    // Drift 8px across the whole break.
    final double dx = 8 * (progress?.value ?? 0.0);
    canvas.save();
    canvas.translate(-dx, 0);
    for (var i = 0; i < cache.paths.length; i++) {
      _p.color = color.withValues(alpha: _alphas[i]);
      canvas.drawPath(cache.paths[i], _p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MountainPainter old) => old.color != color;
}

/// A 128px noise tile generated once and repeated at 3% for paper grain.
class _Grain {
  static ui.Image? tile;
  static Future<void>? _loading;

  static Future<void> load() => _loading ??= _make();

  static Future<void> _make() async {
    const n = 128;
    final rnd = math.Random(42);
    final px = Uint8List(n * n * 4);
    for (var i = 0; i < n * n; i++) {
      final v = rnd.nextInt(256);
      px[i * 4] = v;
      px[i * 4 + 1] = v;
      px[i * 4 + 2] = v;
      px[i * 4 + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      px,
      n,
      n,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    tile = await completer.future;
  }
}

class _GrainPainter extends CustomPainter {
  final Color tint;

  _GrainPainter({required this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    final t = _Grain.tile;
    if (t == null) return;
    final paint = Paint()
      ..shader = ImageShader(
        t,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      )
      ..color = tint.withValues(alpha: 0.03)
      ..blendMode = BlendMode.softLight;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.tint != tint;
}
