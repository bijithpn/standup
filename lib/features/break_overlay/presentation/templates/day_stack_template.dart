import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class DayStackTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const DayStackTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  static const double _blockW = 120;
  static const double _blockH = 14;
  static const double _gap = 6;
  static const double _baseline = 560;
  static const int _maxVisible = 24;

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final kind = BreakKind.of(breakInfo);
    final accent = palette.accentOn(
      breakAccent(settings, 'day_stack', BreakOverlayTheme.sky),
    );
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = remainingSeconds <= 0 && totalSeconds > 0;
    final preview = BreakPreviewScope.isPreview(context);

    return ListenableBuilder(
      listenable: sl<StatsService>(),
      builder: (context, _) {
        // Thumbnails show a representative stack even on a fresh install.
        final completed = preview
            ? 6
            : sl<StatsService>().stats.breaksCompleted;
        // The active block takes one of the 24 slots.
        final shown = completed.clamp(0, _maxVisible - 1);
        final hidden = completed - shown;

        return BreakScaffold(
          onSkip: onSkip,
          strictMode: settings.strictMode,
          accent: accent,
          child: Stack(
            children: [
              Positioned(
                left: 200,
                top: 300,
                child: Semantics(
                  label: '$completed breaks completed today',
                  excludeSemantics: true,
                  child: BreakEntrance(
                    scale: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BreakLabel('Today', textAlign: TextAlign.left),
                        const SizedBox(height: 8),
                        Text(
                          '$completed',
                          style: BreakOverlayTheme.display.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        if (hidden > 0) ...[
                          const SizedBox(height: 4),
                          BreakLabel('+$hidden', textAlign: TextAlign.left),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Completed blocks from the bottom up, then the active block.
              for (var i = 0; i < shown; i++)
                Positioned(
                  left: 640 - _blockW / 2,
                  top: _baseline - (i + 1) * _blockH - i * _gap,
                  child: BreakEntrance(
                    delay: Duration(milliseconds: 30 * i),
                    scale: false,
                    child: _Block(
                      color: accent.withValues(alpha: 0.35),
                      track: null,
                    ),
                  ),
                ),
              Positioned(
                left: 640 - _blockW / 2,
                top: _baseline - (shown + 1) * _blockH - shown * _gap,
                child: BreakEntrance(
                  delay: Duration(milliseconds: 30 * shown),
                  scale: false,
                  child: _ActiveBlock(
                    progress: complete ? 1.0 : progress,
                    accent: accent,
                    track: accent.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: _baseline + 20,
                child: Column(
                  children: [
                    BreakEntrance(
                      delay: BreakEntrance.stagger(1),
                      scale: false,
                      child: BreakCountdown(
                        seconds: remainingSeconds,
                        style: BreakOverlayTheme.title,
                        color: breakClockColor(settings, palette),
                      ),
                    ),
                    const SizedBox(height: 8),
                    BreakEntrance(
                      delay: BreakEntrance.stagger(2),
                      scale: false,
                      child: BreakLabel(kind.label),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  final Color color;
  final Color? track;

  const _Block({required this.color, required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DayStackTemplate._blockW,
      height: DayStackTemplate._blockH,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusSm / 2),
      ),
    );
  }
}

/// The block for the break in progress: fills left to right with a glow.
class _ActiveBlock extends StatelessWidget {
  final double progress;
  final Color accent;
  final Color track;

  const _ActiveBlock({
    required this.progress,
    required this.accent,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(BreakOverlayTheme.radiusSm / 2);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: SizedBox(
          width: DayStackTemplate._blockW,
          height: DayStackTemplate._blockH,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: track)),
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(seconds: 1),
                  builder: (context, v, _) => FractionallySizedBox(
                    widthFactor: v.clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: ColoredBox(color: accent),
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
