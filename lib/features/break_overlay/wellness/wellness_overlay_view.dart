import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_scaffold.dart';
import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_registry.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';
import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';
import 'package:flutter/services.dart';

/// Renders the configured wellness template for a break, compact or immersive,
/// driven only by the overlay's authoritative countdown notifier.
class WellnessOverlayView extends StatefulWidget {
  const WellnessOverlayView({
    super.key,
    required this.config,
    required this.remainingSecondsNotifier,
    required this.onSkip,
    this.onOpenImmersive,
  });

  final OverlayWindowConfig config;
  final ValueNotifier<int> remainingSecondsNotifier;
  final VoidCallback? onSkip;
  final VoidCallback? onOpenImmersive;

  static const _bridge = MethodChannel('com.breakmate.desktop/bridge');

  @override
  State<WellnessOverlayView> createState() => _WellnessOverlayViewState();
}

class _WellnessOverlayViewState extends State<WellnessOverlayView> {
  final int _fallbackStartMs = DateTime.now().millisecondsSinceEpoch;

  OverlayWindowConfig get _c => widget.config;

  String get _instruction {
    final text = (_c.exerciseInstructions?.isNotEmpty ?? false)
        ? _c.exerciseInstructions!
        : _c.tip;
    final eyes = _focus == BreakFocus.eyes;
    return eyes && !text.toLowerCase().contains('look')
        ? '$text Look at something about 20 feet away.'
        : text;
  }

  BreakFocus get _focus =>
      BreakFocus.values.asNameMap()[_c.breakFocus] ?? BreakFocus.eyes;

  BreakSession _session(BuildContext context, int remaining, MotionTier tier) =>
      BreakSession(
        totalSeconds: _c.durationSeconds,
        remainingSeconds: remaining,
        targetEndMs: _c.targetEndTime,
        startedAtMs: _c.breakStartedAtMs ?? _fallbackStartMs,
        paused: _c.paused,
        complete: remaining == 0 || BreakCompletionScope.isCompleting(context),
        focus: _focus,
        tier: tier,
        intensity: _c.motionIntensity,
        timeOfDay: _c.timeOfDay,
        soundscape:
            Soundscape.values.asNameMap()[_c.soundscape] ?? Soundscape.silence,
        strictMode: _c.strictMode,
        title: _c.breakType == 'windDown' ? 'Wind down' : _c.title,
        instruction: _instruction,
      );

  @override
  Widget build(BuildContext context) {
    final template = wellnessTemplateById(_c.breakTemplate);
    final tier = resolveTier(
      animationsEnabled: _c.enableAnimations,
      reduceMotionPref: _c.reduceMotion,
      osReduce:
          prefersReducedMotion ||
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
    );
    final compact = _c.windowMode == 'compact';

    return BreakPaletteScope(
      palette: template.palette,
      child: MotionScope(
        startedAtMs: _c.breakStartedAtMs ?? _fallbackStartMs,
        tier: tier,
        builder: (context, clock) => ValueListenableBuilder<int>(
          valueListenable: widget.remainingSecondsNotifier,
          builder: (context, remaining, _) {
            final s = _session(context, remaining, tier);
            if (compact) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      width: double.infinity,
                      height: 244,
                      child: _EveningWarmth(
                        enabled: s.timeOfDay,
                        radius: 20,
                        child: CompactBreakCard(
                          template: template,
                          session: s,
                          clock: clock,
                          onSkip: widget.onSkip,
                          onOpenImmersive:
                              widget.onOpenImmersive ??
                              () => WellnessOverlayView._bridge.invokeMethod(
                                'openImmersive',
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return BreakScaffold(
              scaled: false,
              palette: template.palette,
              canvas: template.palette.canvas,
              strictMode: _c.strictMode,
              onSkip: widget.onSkip,
              child: _EveningWarmth(
                enabled: s.timeOfDay,
                child: template.immersive(context, s, clock),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Faint amber wash that grows from 18:00; a plain translucent rect, no offscreen layer.
class _EveningWarmth extends StatelessWidget {
  const _EveningWarmth({
    required this.enabled,
    required this.child,
    this.radius = 0,
  });

  final bool enabled;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? breakEveningTint(DateTime.now()) : 0.0;
    if (tint == 0) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: BreakOverlayTheme.amber.withValues(alpha: tint * 0.16),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
