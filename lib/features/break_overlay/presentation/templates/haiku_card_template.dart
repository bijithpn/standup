import 'dart:math' as math;
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
  // Fixed for the whole break so the poem does not change at a minute rollover.
  late final List<String> _poem =
      HaikuCardTemplate._haikus[clock.now().minute % 4];
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);
  final _MountainCache _mountains = _MountainCache();

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

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: BreakSmoothProgress(
        progress: progress,
        builder: (context, anim) => CustomPaint(
          painter: _MountainPainter(
            cache: _mountains,
            progress: reduced ? null : anim,
            color: ink,
          ),
        ),
      ),
      child: Center(
        child: AnimatedOpacity(
          opacity: complete ? 0 : 1,
          duration: BreakMotion.slow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                container: true,
                label: _poem.join(' '),
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _poem.length; i++)
                      BreakEntrance(
                        delay: Duration(milliseconds: 500 * i),
                        scale: false,
                        duration: const Duration(milliseconds: 900),
                        child: Text(
                          _poem[i],
                          textAlign: TextAlign.center,
                          style: BreakOverlayTheme.serif.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.w300,
                            fontStyle: FontStyle.italic,
                            height: 1.7,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 56),
              BreakEntrance(
                delay: BreakEntrance.stagger(4),
                scale: false,
                child: SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      BreakSmoothProgress(
                        progress: progress,
                        builder: (context, anim) => AnimatedBuilder(
                          animation: anim,
                          builder: (context, _) => LinearProgressIndicator(
                            value: anim.value,
                            minHeight: 1,
                            color: accent,
                            backgroundColor: palette.track,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      BreakCountdown(
                        seconds: widget.remainingSeconds,
                        style: BreakOverlayTheme.body.copyWith(
                          fontSize: 14,
                          fontFeatures: BreakOverlayTheme.tabular,
                        ),
                        color: breakClockColor(widget.settings, palette),
                      ),
                    ],
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
