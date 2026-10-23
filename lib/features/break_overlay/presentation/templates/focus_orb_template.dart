import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class FocusOrbTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const FocusOrbTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<FocusOrbTemplate> createState() => _FocusOrbTemplateState();
}

class _FocusOrbTemplateState extends State<FocusOrbTemplate>
    with SingleTickerProviderStateMixin {
  static const Color _cyan = Color(0xFF8BC9D4);

  /// Scale 0.97 -> 1.03 over 6s.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);
  late final double _tint = _eveningTint(DateTime.now());

  _OrbPainter? _painter;
  Object? _painterKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_breath, context, reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  /// 0 before 18:00, ramping to 60% toward amber by 21:00, held after.
  static double _eveningTint(DateTime now) {
    final h = now.hour + now.minute / 60;
    return (((h - 18) / 3).clamp(0.0, 1.0)) * 0.6;
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final base = breakAccent(widget.settings, 'focus_orb', _cyan);
    final hue = Color.lerp(base, BreakOverlayTheme.amber, _tint)!;
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;
    final alphaScale = palette.isDark ? 1.0 : 0.5;

    final key = Object.hash(hue, alphaScale);
    if (_painterKey != key) {
      _painterKey = key;
      _painter = _OrbPainter(
        breath: _breath,
        color: hue,
        alphaScale: alphaScale,
      );
    }

    final shadow = [
      Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
    ];
    final countdownColor = breakClockColor(
      widget.settings,
      palette,
      fallback: palette.isDark ? palette.textPrimary : const Color(0xFF1C1F24),
    );

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: hue,
      background: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.9,
            colors: [hue.withValues(alpha: 0.06), Colors.transparent],
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 640 - 140,
            top: 380 - 140,
            width: 280,
            height: 280,
            child: BreakEntrance(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: complete ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 400),
                builder: (context, finish, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(280, 280),
                        painter: _painter!.withFinish(finish),
                      ),
                    ),
                    child!,
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BreakCountdown(
                      seconds: widget.remainingSeconds,
                      style: BreakOverlayTheme.display.copyWith(
                        shadows: palette.isDark ? shadow : null,
                      ),
                      color: countdownColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _kind.label.toUpperCase(),
                      style: BreakOverlayTheme.micro.copyWith(
                        color: palette.textSecondary,
                        shadows: palette.isDark ? shadow : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Animation<double> breath;
  final Color color;
  final double alphaScale;
  final double finish;

  // Layer radius ratios and alphas; shaders are built once per colour.
  static const _ratios = [0.25, 0.5, 0.75, 1.0];
  static const _alphas = [0.70, 0.35, 0.15, 0.06];
  static const double _overdrive = 1.3; // headroom for the completion flash

  late final List<Paint> _layers;

  _OrbPainter({
    required this.breath,
    required this.color,
    required this.alphaScale,
  }) : finish = 0,
       super(repaint: breath) {
    _layers = [
      for (var i = 0; i < _ratios.length; i++)
        Paint()
          ..shader =
              RadialGradient(
                // Plateau then fall-off: the stack reads as one soft sphere.
                stops: const [0.0, 0.7, 1.0],
                colors: [
                  color.withValues(
                    alpha: (_alphas[i] * _overdrive * alphaScale).clamp(
                      0.0,
                      1.0,
                    ),
                  ),
                  color.withValues(
                    alpha: (_alphas[i] * _overdrive * alphaScale * 0.7).clamp(
                      0.0,
                      1.0,
                    ),
                  ),
                  color.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset.zero, radius: 140 * _ratios[i]),
              ),
    ];
  }

  _OrbPainter._shared(_OrbPainter o, this.finish)
    : breath = o.breath,
      color = o.color,
      alphaScale = o.alphaScale,
      super(repaint: o.breath) {
    _layers = o._layers;
  }

  /// Same cached shaders, different completion flash.
  _OrbPainter withFinish(double f) =>
      f == finish ? this : _OrbPainter._shared(this, f);

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeInOutSine.transform(breath.value);
    final scale = 0.97 + 0.06 * eased;
    // 1.0 -> 1.3x brightness on completion.
    final a = (1 / _overdrive) + (1 - 1 / _overdrive) * finish;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    for (var i = 0; i < _layers.length; i++) {
      _layers[i].color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawCircle(Offset.zero, 140 * _ratios[i], _layers[i]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.color != color ||
      old.alphaScale != alphaScale ||
      old.finish != finish;
}
