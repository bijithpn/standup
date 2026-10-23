import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class StepGuideTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const StepGuideTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  static const double _dot = 28;
  static const double _pitch = 56;
  static const double _left = 400;

  /// Steps are the sentences of the break's tip (up to four).
  List<String> _steps(bool preview) {
    final parsed = breakInfo.tip
        .split('. ')
        .where((s) => s.trim().isNotEmpty)
        .take(4)
        .map((s) => s.trim())
        .map((s) => s.endsWith('.') ? s : '$s.')
        .toList();
    // A one-line tip has no chain to show in a thumbnail.
    if (preview && parsed.length < 3) {
      return const [
        'Look away from the screen.',
        'Focus on something far away.',
        'Blink slowly and relax.',
      ];
    }
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final kind = BreakKind.of(breakInfo);
    final accent = palette.accentOn(
      breakAccent(settings, 'step_guide', BreakOverlayTheme.mint),
    );
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = remainingSeconds <= 0 && totalSeconds > 0;
    final preview = BreakPreviewScope.isPreview(context);
    final steps = _steps(preview);
    final n = steps.length;
    // The active step follows elapsed time; every step is checked at the end.
    final active = complete ? n : (progress * n).floor().clamp(0, n - 1);
    final top = 400 - (n * _pitch) / 2 + 20;

    return BreakScaffold(
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            left: _left,
            top: 96,
            width: 480,
            child: BreakEntrance(
              scale: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Follow these steps',
                        style: BreakOverlayTheme.title.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      BreakCountdown(
                        seconds: remainingSeconds,
                        style: BreakOverlayTheme.title,
                        textAlign: TextAlign.right,
                        color: breakClockColor(settings, palette),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BreakLabel(kind.label, textAlign: TextAlign.left),
                ],
              ),
            ),
          ),
          if (n > 0)
            for (var i = 0; i < n; i++) ...[
              // Track down to the next step; fills as that step elapses.
              if (i < n - 1)
                Positioned(
                  left: _left + _dot / 2 - 1,
                  top: top + i * _pitch + _dot * 1.15 / 2 + _dot / 2,
                  child: _Track(
                    height: _pitch - _dot * 1.15,
                    fill: complete
                        ? 1.0
                        : ((progress - i / n) * n).clamp(0.0, 1.0),
                    accent: accent,
                    track: palette.track,
                  ),
                ),
              Positioned(
                left: _left,
                top: top + i * _pitch,
                width: 480,
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(i + 1),
                  scale: false,
                  child: Semantics(
                    label:
                        'Step ${i + 1} of $n, ${i < active ? 'done' : (i == active ? 'active' : 'upcoming')}',
                    child: Row(
                      children: [
                        _StepDot(
                          number: i + 1,
                          state: i < active
                              ? _StepState.done
                              : (i == active
                                    ? _StepState.active
                                    : _StepState.upcoming),
                          accent: accent,
                          track: palette.track,
                          muted: palette.textMuted,
                          onAccent: palette.canvas,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: BreakMotion.medium,
                            style: BreakOverlayTheme.body.copyWith(
                              color: i == active
                                  ? palette.textPrimary
                                  : palette.textMuted,
                            ),
                            child: Text(steps[i]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

enum _StepState { upcoming, active, done }

class _Track extends StatelessWidget {
  final double height;
  final double fill;
  final Color accent;
  final Color track;

  const _Track({
    required this.height,
    required this.fill,
    required this.accent,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: track)),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fill),
              duration: const Duration(seconds: 1),
              builder: (context, v, _) => FractionallySizedBox(
                heightFactor: v,
                alignment: Alignment.topCenter,
                child: ColoredBox(color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatefulWidget {
  final int number;
  final _StepState state;
  final Color accent;
  final Color track;
  final Color muted;
  final Color onAccent;

  const _StepDot({
    required this.number,
    required this.state,
    required this.accent,
    required this.track,
    required this.muted,
    required this.onAccent,
  });

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot>
    with SingleTickerProviderStateMixin {
  /// Glow pulse when the step turns into a check (260ms).
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _StepDot old) {
    super.didUpdateWidget(old);
    if (old.state != _StepState.done &&
        widget.state == _StepState.done &&
        !BreakMotion.reduced(context)) {
      _glow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = BreakMotion.reduced(context);
    final s = widget.state;
    final filled = s == _StepState.active;
    final scale = (s == _StepState.active && !reduced) ? 1.15 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: BreakMotion.medium,
      curve: BreakMotion.enter,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) => Container(
          width: StepGuideTemplate._dot,
          height: StepGuideTemplate._dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? widget.accent : Colors.transparent,
            border: Border.all(
              color: s == _StepState.upcoming ? widget.track : widget.accent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(
                  alpha: s == _StepState.done ? 0.5 * (1 - _glow.value) : 0,
                ),
                blurRadius: 14,
              ),
            ],
          ),
          child: child,
        ),
        // The number scales out, then the check scales in.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => reduced
              ? FadeTransition(opacity: anim, child: child)
              : ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
          child: s == _StepState.done
              ? Icon(
                  Icons.check_rounded,
                  key: const ValueKey('check'),
                  size: 16,
                  color: widget.accent,
                )
              : Text(
                  '${widget.number}',
                  key: ValueKey('n${widget.number}'),
                  style: TextStyle(
                    fontFamily: BreakOverlayTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: filled ? widget.onAccent : widget.muted,
                    fontFeatures: BreakOverlayTheme.tabular,
                  ),
                ),
        ),
      ),
    );
  }
}
