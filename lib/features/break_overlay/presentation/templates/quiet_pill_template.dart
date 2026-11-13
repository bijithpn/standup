import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _mint = Color(0xFF8FD8C2);
const _smoke = Color(0xFF12171E);
const _mist = Color(0xFFE6EEF0);

/// Break template: small unobtrusive pill that springs open on hover or focus to show the countdown, tip and skip.
class QuietPillTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const QuietPillTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<QuietPillTemplate> createState() => _QuietPillTemplateState();
}

class _QuietPillTemplateState extends State<QuietPillTemplate>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _focus = false;
  bool _pinned = false;

  // Expands on hover, keyboard focus, or when pinned open.
  bool get _expanded => _hover || _focus || _pinned;

  late final AnimationController _size = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  Color get _accent => BreakOverlayTheme.resolveAccent(
    widget.settings.templateAccentOverrides,
    'quiet_pill',
    _mint,
  );

  @override
  void dispose() {
    _size.dispose();
    super.dispose();
  }

  void _syncSize() {
    final target = _expanded ? 1.0 : 0.0;
    if (breakShouldFreeze(context)) {
      _size.value = target;
      return;
    }
    _size.animateWith(
      SpringSimulation(BreakMotion.spring, _size.value, target, _size.velocity),
    );
  }

  void _setHover(bool v) {
    setState(() => _hover = v);
    _syncSize();
  }

  void _setFocus(bool v) {
    setState(() => _focus = v);
    _syncSize();
  }

  @override
  Widget build(BuildContext context) {
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final canSkip = breakCanSkip(widget.settings, widget.onSkip);
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    final pill = AnimatedBuilder(
      animation: _size,
      builder: (context, _) {
        final t = _size.value;
        final w = 200 + 120 * t;
        final h = 36 + 20 * t;
        return Opacity(
          opacity: 0.7 + 0.3 * t.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _smoke.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
              border: Border.all(color: _mist.withValues(alpha: 0.10)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BreakSmoothProgress(
                      progress: progress,
                      builder: (context, anim) => AnimatedBuilder(
                        animation: anim,
                        builder: (context, _) => Align(
                          alignment: Alignment.bottomLeft,
                          child: FractionallySizedBox(
                            widthFactor: anim.value.clamp(0.0, 1.0),
                            child: SizedBox(
                              height: 2,
                              child: ColoredBox(
                                color: _accent.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16 + 2 * t, 0, 14, 0),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 6),
                          ),
                          const SizedBox(width: 10),
                          BreakCountdown(
                            seconds: widget.remainingSeconds,
                            style: const TextStyle(
                              fontFamily: BreakOverlayTheme.monoFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFeatures: BreakOverlayTheme.tabular,
                              height: 1.0,
                            ),
                            color: breakClockColor(
                              widget.settings,
                              BreakPalette.dark,
                              fallback: _mist,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _kind.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: BreakOverlayTheme.micro.copyWith(
                                color: _mist.withValues(alpha: 0.55),
                                height: 1.0,
                              ),
                            ),
                          ),
                          if (t > 0.6 && canSkip)
                            BreakSkipIcon(
                              onPressed: widget.onSkip!,
                              accent: _accent,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return BreakScaffold(
      canvas: Colors.transparent,
      scrim: _smoke.withValues(alpha: 0.20),
      scaled: false,
      showSkip: false,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
      child: BreakDraggable(
        initialAnchor: Alignment.bottomCenter,
        inset: 40,
        child: Semantics(
          container: true,
          label: 'Break timer, ${widget.remainingSeconds} seconds remaining',
          child: MouseRegion(
            onEnter: (_) => _setHover(true),
            onExit: (_) => _setHover(false),
            child: FocusableActionDetector(
              onShowFocusHighlight: _setFocus,
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    setState(() => _pinned = !_pinned);
                    _syncSize();
                    return null;
                  },
                ),
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: BreakMotion.fast,
                    curve: BreakMotion.enter,
                    alignment: Alignment.bottomCenter,
                    child: _expanded && showTip
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _smoke.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(
                                    BreakOverlayTheme.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: _mist.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    widget.breakInfo.tip,
                                    textAlign: TextAlign.center,
                                    style: BreakOverlayTheme.body.copyWith(
                                      color: _mist.withValues(alpha: 0.75),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(width: 0, height: 0),
                  ),
                  pill,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
