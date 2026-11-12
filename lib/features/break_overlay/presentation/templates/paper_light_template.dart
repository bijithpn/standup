import 'package:flutter/material.dart';
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

  /// Black for 120ms, then a 200ms fade: a page turn on entrance.
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
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BreakEntrance(
                  scale: false,
                  child: Text(_kind.label, style: _serif(20, _stone)),
                ),
                const SizedBox(height: 20),
                BreakEntrance(
                  delay: BreakEntrance.stagger(1),
                  scale: false,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    style: _serif(
                      112,
                      _ink,
                      weight: FontWeight.w300,
                    ).copyWith(height: 1.0, letterSpacing: -2),
                    color: breakClockColor(
                      widget.settings,
                      BreakPalette.paper,
                      fallback: _ink,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                BreakEntrance(
                  delay: BreakEntrance.stagger(2),
                  scale: false,
                  child: SizedBox(
                    width: 240,
                    child: BreakSmoothProgress(
                      progress: progress,
                      builder: (context, anim) => AnimatedBuilder(
                        animation: anim,
                        builder: (context, _) => LinearProgressIndicator(
                          value: anim.value,
                          minHeight: 1,
                          color: forest,
                          backgroundColor: BreakPalette.paper.track,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showTip) ...[
                  const SizedBox(height: 32),
                  BreakEntrance(
                    delay: BreakEntrance.stagger(3),
                    scale: false,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Text(
                        widget.breakInfo.tip,
                        textAlign: TextAlign.center,
                        style: _serif(
                          20,
                          BreakPalette.paper.textSecondary,
                        ).copyWith(height: 1.5, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flash,
                builder: (context, _) {
                  if (!_flash.isAnimating) return const SizedBox.shrink();
                  final t = _flash.value;
                  final opacity = t <= 0.375 ? 1.0 : 1.0 - (t - 0.375) / 0.625;
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
