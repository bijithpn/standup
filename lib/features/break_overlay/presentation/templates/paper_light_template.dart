import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class PaperLightTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const PaperLightTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<PaperLightTemplate> createState() => _PaperLightTemplateState();
}

class _PaperLightTemplateState extends State<PaperLightTemplate>
    with SingleTickerProviderStateMixin {
  static const Color _ink = Color(
    0xFF1A1814,
  ); // == BreakPalette.paper.textPrimary
  static const Color _stone = Color(0xFF6B6560); // 5.2:1 on the cream
  static const Color _forest = Color(0xFF2D6A4F);

  /// E-ink style flash on entrance: black for 120ms, then a 200ms fade.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  bool _started = false;
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!breakShouldFreeze(context)) _flash.forward();
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  TextStyle _serif(double size, Color color, {FontWeight? weight}) =>
      BreakOverlayTheme.serif.copyWith(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        color: color,
        fontFeatures: BreakOverlayTheme.tabular,
      );

  @override
  Widget build(BuildContext context) {
    final forest = BreakOverlayTheme.resolveAccent(
      widget.settings.templateAccentOverrides,
      'paper_light',
      _forest,
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      palette: BreakPalette.paper,
      canvas: BreakPalette.paper.canvas,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: forest,
      child: Stack(
        children: [
          // Hairline, then the label hanging under it.
          Positioned(
            left: 240,
            top: 160,
            width: 800,
            child: BreakEntrance(
              scale: false,
              child: Container(height: 1, color: _ink.withValues(alpha: 0.15)),
            ),
          ),
          Positioned(
            left: 240,
            top: 184,
            width: 800,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(LucideIcons.leaf, size: 16, color: forest),
                  ),
                  const SizedBox(width: 8),
                  BreakLabel(_kind.label, color: _stone),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 360 - 40,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(2),
              scale: false,
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                style: _serif(72, _ink).copyWith(height: 1.0),
                color: breakClockColor(
                  widget.settings,
                  BreakPalette.paper,
                  fallback: _ink,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 360 + 36 + 24,
            child: Center(
              child: BreakEntrance(
                delay: BreakEntrance.stagger(3),
                scale: false,
                child: SizedBox(
                  width: 320,
                  height: 2,
                  child: BreakSmoothProgress(
                    progress: progress,
                    builder: (context, anim) => CustomPaint(
                      painter: _Rule(
                        progress: anim,
                        color: forest,
                        track: _ink.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 0,
              right: 0,
              top: 360 + 36 + 24 + 36,
              child: Center(
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(4),
                  scale: false,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      widget.breakInfo.tip,
                      textAlign: TextAlign.center,
                      style: _serif(16, _stone).copyWith(height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          // E-ink flash.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flash,
                builder: (context, _) {
                  final t = _flash.value;
                  // Hold black for the first 120ms of 320ms, then fade out.
                  final opacity = t <= 0.375 ? 1.0 : 1.0 - (t - 0.375) / 0.625;
                  if (!_flash.isAnimating) return const SizedBox.shrink();
                  return ColoredBox(
                    color: Colors.black.withValues(alpha: opacity.clamp(0, 1)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule extends CustomPainter {
  final Animation<double> progress;
  final Color color;
  final Color track;

  _Rule({required this.progress, required this.color, required this.track})
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    p.color = track;
    canvas.drawRect(Offset.zero & size, p);
    p.color = color;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * progress.value, size.height),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _Rule old) =>
      old.color != color || old.track != track;
}
