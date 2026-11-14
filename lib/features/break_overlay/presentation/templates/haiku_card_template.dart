import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

/// Break template: a haiku card over layered mountains; the poem is picked by the current minute.
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
  late final List<String> _poem =
      HaikuCardTemplate._haikus[clock.now().minute % 4];
  final _MountainCache _mountains = _MountainCache();

  static const _washi = BreakPalette(
    canvas: Color(0xFF202724),
    canvasRaised: Color(0xFF29322C),
    surface: Color(0xFF29322C),
    border: Color(0x426B746B),
    track: Color(0x426B746B),
    textPrimary: Color(0xFFDFE4D8),
    textSecondary: Color(0xFFBBC7B7),
    textMuted: Color(0xFFA3B29E),
    isDark: true,
  );
  static const _vermilion = Color(0xFFC8402B);

  @override
  Widget build(BuildContext context) {
    final seal = breakAccent(widget.settings, 'haiku_card', _vermilion);
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

    return BreakScaffold(
      palette: _washi,
      canvas: _washi.canvas,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: seal,
      background: BreakSmoothProgress(
        progress: progress,
        builder: (context, anim) => CustomPaint(
          painter: _MountainPainter(
            cache: _mountains,
            progress: reduced ? null : anim,
          ),
        ),
      ),
      child: AnimatedOpacity(
        opacity: complete ? 0 : 1,
        duration: BreakMotion.slow,
        child: Stack(
          children: [
            Positioned(
              left: 128,
              top: 150,
              child: Semantics(
                container: true,
                label: _poem.join(' '),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _poem.length; i++)
                      BreakEntrance(
                        delay: Duration(milliseconds: 500 * i),
                        scale: false,
                        duration: const Duration(milliseconds: 900),
                        child: Padding(
                          padding: EdgeInsets.only(left: 0),
                          child: Text(
                            _poem[i],
                            style: BreakOverlayTheme.serif.copyWith(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                              height: 1.55,
                              color: _washi.textPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 128,
              top: 96,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(4),
                scale: false,
                child: Container(
                  width: 124,
                  height: 124,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _washi.surface,
                    border: Border.all(color: _washi.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    width: 108,
                    height: 108,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _washi.canvas.withValues(alpha: 0.6),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: BreakCountdown(
                      seconds: widget.remainingSeconds,
                      style: BreakOverlayTheme.serif.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        fontFeatures: BreakOverlayTheme.tabular,
                      ),
                      color: breakClockColor(
                        widget.settings,
                        _washi,
                        fallback: _washi.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MountainCache {
  Size? size;
  final List<Path> paths = [];

  static const _ridges = [
    (base: 0.62, amp: 0.10, seed: 3.0),
    (base: 0.72, amp: 0.12, seed: 7.0),
    (base: 0.84, amp: 0.10, seed: 11.0),
    (base: 0.95, amp: 0.07, seed: 17.0),
  ];

  void build(Size s) {
    if (size == s) return;
    size = s;
    paths.clear();
    for (final r in _ridges) {
      final path = Path()..moveTo(-20, s.height);
      for (var i = 0; i <= 64; i++) {
        final t = i / 64;
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

  static const _ridgeColors = [
    Color(0xFF354038),
    Color(0xFF2C3831),
    Color(0xFF25312B),
    Color(0xFF1A241F),
  ];
  final Paint _p = Paint();

  _MountainPainter({required this.cache, required this.progress})
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    cache.build(size);
    _p.color = const Color(0xFF626951);
    canvas.drawCircle(
      Offset(size.width * 0.66, size.height * 0.5),
      size.height * 0.13,
      _p,
    );
    final double dx = 8 * (progress?.value ?? 0.0);
    canvas.save();
    canvas.translate(-dx, 0);
    for (var i = 0; i < cache.paths.length; i++) {
      _p.color = _ridgeColors[i];
      canvas.drawPath(cache.paths[i], _p);
      if (i < 2) {
        final top = size.height * (0.55 + 0.1 * i);
        _p.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x00202724), const Color(0xB3202724)],
        ).createShader(Rect.fromLTWH(0, top, size.width, size.height * 0.2));
        canvas.drawRect(
          Rect.fromLTWH(-20, top, size.width + 40, size.height * 0.2),
          _p,
        );
        _p.shader = null;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MountainPainter old) => false;
}
