import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class SoftFloatingWidgetTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const SoftFloatingWidgetTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<SoftFloatingWidgetTemplate> createState() =>
      _SoftFloatingWidgetTemplateState();
}

class _SoftFloatingWidgetTemplateState extends State<SoftFloatingWidgetTemplate>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  /// Gentle float: +-4px over a 3s period.
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  Color get _accent => BreakPalette.of(context).accentOn(
    BreakOverlayTheme.resolveAccent(
      widget.settings.templateAccentOverrides,
      'floating',
      _kind.accent,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_pulseController, context, park: 0.0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;
    final canSkip = breakCanSkip(widget.settings, widget.onSkip);
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    final card = BreakGlass(
      radius: BreakOverlayTheme.radiusLg,
      fillAlpha: palette.isDark ? 0.6 : 0.7,
      borderAlpha: _hovered ? 0.25 : (palette.isDark ? 0.15 : 0.08),
      borderColor: null,
      child: SizedBox(
        width: 280,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        BreakProgressRing(
                          size: 28,
                          strokeWidth: 2.5,
                          progress: progress,
                          color: _accent,
                          trackColor: palette.track,
                          flash: complete ? 0.5 : 0,
                          child: ExcludeSemantics(
                            child: Icon(_kind.icon, size: 14, color: _accent),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BreakCountdown(
                                seconds: widget.remainingSeconds,
                                style: BreakOverlayTheme.title.copyWith(
                                  height: 1.1,
                                ),
                                color: breakClockColor(
                                  widget.settings,
                                  palette,
                                ),
                                textAlign: TextAlign.left,
                              ),
                              BreakLabel(
                                _kind.label,
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                        if (canSkip)
                          BreakSkipIcon(
                            onPressed: widget.onSkip!,
                            accent: _accent,
                          ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: BreakMotion.fast,
                    curve: BreakMotion.enter,
                    alignment: Alignment.topCenter,
                    child: _hovered && showTip
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              widget.breakInfo.tip,
                              style: BreakOverlayTheme.body.copyWith(
                                color: palette.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            // 2px progress line along the bottom inner edge.
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: SizedBox(
                  height: 2,
                  child: Stack(
                    children: [
                      ColoredBox(
                        color: palette.track,
                        child: const SizedBox.expand(),
                      ),
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: progress),
                          duration: const Duration(seconds: 1),
                          builder: (context, v, _) => FractionallySizedBox(
                            widthFactor: v,
                            alignment: Alignment.centerLeft,
                            child: ColoredBox(color: _accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return BreakScaffold(
      canvas: Colors.transparent,
      scrim: palette.canvas.withValues(alpha: 0.15),
      scaled: false,
      showSkip: false,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
      child: BreakDraggable(
        initialAnchor: Alignment.bottomRight,
        child: Semantics(
          container: true,
          label: 'Break timer, ${widget.remainingSeconds} seconds remaining',
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  0,
                  4 * math.sin(_pulseController.value * 2 * math.pi),
                ),
                child: child,
              ),
              child: BreakCompletionPulse(complete: complete, child: card),
            ),
          ),
        ),
      ),
    );
  }
}
