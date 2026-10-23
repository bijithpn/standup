import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class NightSkyTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const NightSkyTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<NightSkyTemplate> createState() => _NightSkyTemplateState();
}

class _Star {
  final double dx;
  final double dy;
  final double size;
  final double phase;
  const _Star({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
  });
}

class _NightSkyTemplateState extends State<NightSkyTemplate>
    with TickerProviderStateMixin {
  /// The night is always dark, so this ignores the light/dark theme.
  static const BreakPalette _night = BreakPalette(
    canvas: Color(0xFF0A0E27),
    canvasRaised: Color(0xFF141A3A),
    surface: Color(0xFF141A3A),
    border: Color(0x33FFFFFF),
    track: Color(0x33FFFFFF),
    textPrimary: Color(0xFFF2F4F7),
    textSecondary: Color(0xFFD0D6E6),
    textMuted: Color(0xFFB4BCD2),
    isDark: true,
  );

  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  /// One meteor streak, 700ms. At most one is ever in flight.
  late final AnimationController _meteor = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Timer? _meteorTimer;
  final math.Random _rand = math.Random(11);
  _MeteorPath _path = const _MeteorPath(0.62, 0.12, 0.8, 0.6);

  late final List<_Star> _stars;
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void initState() {
    super.initState();
    final rand = math.Random(7);
    _stars = List.generate(
      100,
      (_) => _Star(
        dx: rand.nextDouble(),
        dy: rand.nextDouble(),
        size: 1.0 + rand.nextDouble() * 1.6,
        phase: rand.nextDouble() * 2 * math.pi,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_twinkle, context);
    _meteorTimer?.cancel();
    if (BreakPreviewScope.isPreview(context)) {
      _meteor.value = 0.5; // one meteor caught mid-streak
    } else if (!BreakMotion.reduced(context)) {
      _scheduleMeteor();
    }
  }

  void _scheduleMeteor() {
    // A streak every 6-14 seconds; the next is queued only after this ends.
    final wait = Duration(milliseconds: 6000 + _rand.nextInt(8000));
    _meteorTimer = Timer(wait, () {
      if (!mounted) return;
      setState(() {
        _path = _MeteorPath(
          0.25 + _rand.nextDouble() * 0.65,
          _rand.nextDouble() * 0.25,
          -0.75 - _rand.nextDouble() * 0.25,
          0.55 + _rand.nextDouble() * 0.2,
        );
      });
      _meteor.forward(from: 0).whenComplete(() {
        if (mounted) _scheduleMeteor();
      });
    });
  }

  @override
  void dispose() {
    _meteorTimer?.cancel();
    _twinkle.dispose();
    _meteor.dispose();
    super.dispose();
  }

  bool get _isEnding =>
      widget.remainingSeconds <= 0 ||
      breakProgress(widget.remainingSeconds, widget.totalSeconds) >= 0.95;

  @override
  Widget build(BuildContext context) {
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;
    final accent = BreakOverlayTheme.dusk;

    return BreakScaffold(
      palette: _night,
      canvas: _night.canvas,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      showSkip: !_isEnding,
      accent: accent,
      background: BreakSmoothProgress(
        progress: progress,
        builder: (context, anim) => CustomPaint(
          painter: _SkyPainter(
            stars: _stars,
            twinkle: _twinkle,
            meteor: _meteor,
            progress: anim,
            totalSeconds: widget.totalSeconds,
            meteorPath: _path,
            showMeteor: !BreakMotion.reduced(context),
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 400 - 150,
            child: Column(
              children: [
                BreakEntrance(
                  scale: false,
                  child: AnimatedSwitcher(
                    duration: BreakMotion.medium,
                    switchInCurve: BreakMotion.enter,
                    child: Column(
                      key: ValueKey(_isEnding),
                      children: [
                        // The break's own label; "Time to Switch Off" collided
                        // with the end-of-day Wind Down screen.
                        Text(
                          _isEnding ? 'Recharged & Ready' : _kind.label,
                          textAlign: TextAlign.center,
                          style: BreakOverlayTheme.title.copyWith(
                            color: _night.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Text(
                            _isEnding
                                ? "That time away was well-invested. Now "
                                      "you're ready to tackle whatever comes "
                                      "next with fresh perspective."
                                : (showTip ? widget.breakInfo.tip : ''),
                            textAlign: TextAlign.center,
                            style: BreakOverlayTheme.body.copyWith(
                              color: _night.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                BreakEntrance(
                  delay: BreakEntrance.stagger(1),
                  scale: false,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    color: breakClockColor(widget.settings, _night),
                  ),
                ),
              ],
            ),
          ),
          if (_isEnding && widget.onSkip != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Center(child: _CompletePill(onTap: widget.onSkip!)),
            ),
        ],
      ),
    );
  }
}

class _MeteorPath {
  /// Start (fraction of width/height) and direction (dx, dy) of the streak.
  final double x;
  final double y;
  final double dx;
  final double dy;
  const _MeteorPath(this.x, this.y, this.dx, this.dy);
}

class _CompletePill extends StatefulWidget {
  final VoidCallback onTap;

  const _CompletePill({required this.onTap});

  @override
  State<_CompletePill> createState() => _CompletePillState();
}

class _CompletePillState extends State<_CompletePill> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Complete session',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: BreakMotion.fast,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: _hovered ? 1.0 : 0.92),
              shape: StadiumBorder(
                side: _focused
                    ? const BorderSide(color: Color(0xFFF5B971), width: 2)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              'Complete Session',
              style: BreakOverlayTheme.body.copyWith(
                color: const Color(0xFF0A0E27),
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient, stars, constellation lines, meteor and dawn glow in one pass.
class _SkyPainter extends CustomPainter {
  final List<_Star> stars;
  final Animation<double> twinkle;
  final Animation<double> meteor;
  final Animation<double> progress;
  final int totalSeconds;
  final _MeteorPath meteorPath;
  final bool showMeteor;

  // Orion and Cassiopeia as normalised polylines.
  static const _orion = [
    [Offset(0.20, 0.22), Offset(0.24, 0.33), Offset(0.27, 0.40)],
    [Offset(0.33, 0.20), Offset(0.30, 0.33), Offset(0.27, 0.40)],
    [Offset(0.27, 0.40), Offset(0.30, 0.41), Offset(0.33, 0.42)],
    [Offset(0.24, 0.33), Offset(0.30, 0.33)],
    [Offset(0.27, 0.40), Offset(0.24, 0.55)],
    [Offset(0.33, 0.42), Offset(0.35, 0.56)],
  ];
  static const _cassiopeia = [
    [
      Offset(0.66, 0.16),
      Offset(0.70, 0.24),
      Offset(0.75, 0.18),
      Offset(0.80, 0.26),
      Offset(0.85, 0.17),
    ],
  ];

  final Paint _sky = Paint();
  final Paint _star = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _dawn = Paint();
  final Paint _tail = Paint()
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  _SkyPainter({
    required this.stars,
    required this.twinkle,
    required this.meteor,
    required this.progress,
    required this.totalSeconds,
    required this.meteorPath,
    required this.showMeteor,
  }) : super(repaint: Listenable.merge([twinkle, meteor, progress]));

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final full = Offset.zero & size;

    _sky.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0A0E27), Color(0xFF6D3B8C), Color(0xFF05060F)],
    ).createShader(full);
    canvas.drawRect(full, _sky);

    // Dawn ramps up over the final 10 seconds.
    final remaining = (1 - progress.value) * totalSeconds;
    final dawn = totalSeconds <= 0
        ? 0.0
        : ((10 - remaining) / 10).clamp(0.0, 1.0);

    // Stars dim as the dawn arrives.
    final starFade = 1 - 0.7 * dawn;
    final t = twinkle.value;
    for (final s in stars) {
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + s.phase));
      _star.color = Colors.white.withValues(alpha: 0.3 + 0.6 * tw * starFade);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.size,
        _star,
      );
    }

    _line.color = Colors.white.withValues(alpha: 0.08 * starFade);
    for (final group in [..._orion, ..._cassiopeia]) {
      final path = Path()
        ..moveTo(group.first.dx * size.width, group.first.dy * size.height);
      for (final p in group.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, _line);
    }

    if (showMeteor && meteor.value > 0 && meteor.value < 1) {
      final k = size.shortestSide / 800;
      final dir = Offset(meteorPath.dx, meteorPath.dy);
      final unit = dir / dir.distance;
      final start = Offset(
        meteorPath.x * size.width,
        meteorPath.y * size.height,
      );
      final head = start + unit * (meteor.value * 520 * k);
      final tail = head - unit * (120 * k);
      _tail.shader = LinearGradient(
        colors: [Colors.white.withValues(alpha: 0), Colors.white],
      ).createShader(Rect.fromPoints(tail, head));
      canvas.drawLine(tail, head, _tail);
      _star.color = Colors.white;
      canvas.drawCircle(head, 2, _star);
    }

    if (dawn > 0) {
      _dawn.shader = RadialGradient(
        center: const Alignment(0, 1.1),
        radius: 1.0,
        colors: [
          const Color(0xFFF5B971).withValues(alpha: 0.40 * dawn),
          const Color(0xFFF5B971).withValues(alpha: 0),
        ],
      ).createShader(full);
      canvas.drawRect(full, _dawn);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.meteorPath != meteorPath ||
      old.showMeteor != showMeteor ||
      old.totalSeconds != totalSeconds;
}
