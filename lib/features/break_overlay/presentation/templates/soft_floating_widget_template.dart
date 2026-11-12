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

  /// Where the card was last left. Lives for the process, so the next break's
  /// overlay opens where this one was dropped.
  @visibleForTesting
  static Alignment lastAnchor = Alignment.bottomRight;

  @override
  State<SoftFloatingWidgetTemplate> createState() =>
      _SoftFloatingWidgetTemplateState();
}

class _SoftFloatingWidgetTemplateState
    extends State<SoftFloatingWidgetTemplate> {
  bool _hovered = false;

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  Color get _accent => BreakPalette.of(context).accentOn(
    BreakOverlayTheme.resolveAccent(
      widget.settings.templateAccentOverrides,
      'floating',
      _kind.accent,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final canSkip = breakCanSkip(widget.settings, widget.onSkip);
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    final card = BreakGlass(
      radius: BreakOverlayTheme.radiusLg,
      fillAlpha: palette.isDark ? 0.6 : 0.7,
      borderColor: palette.border,
      shadow: false,
      child: SizedBox(
        width: 260,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BreakCountdown(
                          seconds: widget.remainingSeconds,
                          style: BreakOverlayTheme.title.copyWith(
                            fontWeight: FontWeight.w300,
                            height: 1.1,
                          ),
                          color: breakClockColor(widget.settings, palette),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 2),
                        BreakLabel(_kind.label, textAlign: TextAlign.left),
                      ],
                    ),
                  ),
                  if (canSkip)
                    BreakSkipIcon(onPressed: widget.onSkip!, accent: _accent),
                ],
              ),
              AnimatedSize(
                duration: BreakMotion.fast,
                curve: BreakMotion.enter,
                alignment: Alignment.topCenter,
                child: _hovered && showTip
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12, right: 8),
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
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
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
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: progress),
                          duration: const Duration(seconds: 1),
                          builder: (context, v, _) => FractionallySizedBox(
                            widthFactor: v,
                            alignment: Alignment.centerLeft,
                            child: ColoredBox(color: _accent),
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
        initialAnchor: SoftFloatingWidgetTemplate.lastAnchor,
        onAnchorChanged: (a) => SoftFloatingWidgetTemplate.lastAnchor = a,
        child: Semantics(
          container: true,
          label: 'Break timer, ${widget.remainingSeconds} seconds remaining',
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: BreakCompletionPulse(complete: complete, child: card),
          ),
        ),
      ),
    );
  }
}
