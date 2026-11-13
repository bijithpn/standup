import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _apricot = Color(0xFFF0B27A);
const _umber = Color(0xFF211A17);
const _cream = Color(0xFFF6ECE0);
const _warm = BreakPalette(
  canvas: _umber,
  canvasRaised: _umber,
  surface: _umber,
  border: Color(0x1FF0B27A),
  track: Color(0x1FF6ECE0),
  textPrimary: _cream,
  textSecondary: _cream,
  textMuted: _cream,
  isDark: true,
);

/// Break template: a draggable glass card that snaps to a screen anchor, leaving the rest of the desktop visible.
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

  // Remembers the last dragged position for tests.
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

  Color get _accent => BreakOverlayTheme.resolveAccent(
    widget.settings.templateAccentOverrides,
    'floating',
    _apricot,
  );

  @override
  Widget build(BuildContext context) {
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

    final card = BreakPaletteScope(
      palette: _warm,
      child: BreakGlass(
        radius: BreakOverlayTheme.radiusLg,
        fillAlpha: 0.96,
        borderColor: _apricot.withValues(alpha: 0.22),
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
                          BreakLabel(
                            _kind.label,
                            color: _accent,
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: BreakCountdown(
                              seconds: widget.remainingSeconds,
                              style: const TextStyle(
                                fontFamily: BreakOverlayTheme.serifFamily,
                                fontSize: 38,
                                fontWeight: FontWeight.w300,
                                fontFeatures: BreakOverlayTheme.tabular,
                                height: 1.0,
                              ),
                              color: breakClockColor(
                                widget.settings,
                                BreakPalette.dark,
                                fallback: _cream,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canSkip) ...[
                      const SizedBox(width: 12),
                      BreakSkipIcon(onPressed: widget.onSkip!, accent: _accent),
                    ],
                  ],
                ),
                AnimatedSize(
                  duration: BreakMotion.fast,
                  curve: BreakMotion.enter,
                  alignment: Alignment.topCenter,
                  child:
                      (_hovered || BreakPreviewScope.isPreview(context)) &&
                          showTip
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12, right: 8),
                          child: Text(
                            widget.breakInfo.tip,
                            style: BreakOverlayTheme.body.copyWith(
                              color: _cream.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1.5),
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          ColoredBox(
                            color: _cream.withValues(alpha: 0.12),
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
      ),
    );

    return BreakScaffold(
      canvas: Colors.transparent,
      scrim: _umber.withValues(alpha: 0.15),
      scaled: false,
      showSkip: false,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
      child: BreakDraggable(
        initialAnchor: BreakPreviewScope.isPreview(context)
            ? Alignment.center
            : SoftFloatingWidgetTemplate.lastAnchor,
        inset: BreakPreviewScope.isPreview(context) ? 12 : 32,
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
