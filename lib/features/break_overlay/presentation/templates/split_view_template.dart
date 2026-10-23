import 'dart:async';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/domain/break_tips.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class SplitViewTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const SplitViewTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<SplitViewTemplate> createState() => _SplitViewTemplateState();
}

class _SplitViewTemplateState extends State<SplitViewTemplate> {
  Timer? _timer;
  int _index = 0;
  bool _hovering = false;
  bool _manual = false; // true only right after the user changed the tip
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  /// Guidance shown on the right: the break's tip, plus why it started when
  /// that is known.
  List<({String title, String body})> get _items => [
    if (widget.breakInfo.tip.isNotEmpty)
      (title: _kind.label, body: widget.breakInfo.tip),
    if (widget.settings.showExercisesInBreak &&
        widget.breakInfo.triggerReason != null &&
        widget.breakInfo.triggerReason!.isNotEmpty)
      (title: 'Why now', body: widget.breakInfo.triggerReason!),
    for (final tip in BreakTips.extra(widget.breakInfo))
      (title: 'Tip', body: tip),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    // A Timer, not a ticker: this only needs to wake every 8 seconds.
    if (!breakShouldFreeze(context)) {
      _timer = Timer.periodic(const Duration(seconds: 8), (_) {
        final n = _items.length;
        if (!mounted || _hovering || n < 2) return;
        setState(() {
          _index = (_index + 1) % n;
          _manual = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      BreakOverlayTheme.resolveAccent(
        widget.settings.templateAccentOverrides,
        'split_view',
        _kind.accent,
      ),
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;
    final items = _items;
    final index = items.isEmpty ? 0 : _index.clamp(0, items.length - 1);
    final reduced = BreakMotion.reduced(context);

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: Row(
        children: [
          Expanded(child: ColoredBox(color: palette.canvas)),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(left: BorderSide(color: palette.border)),
              ),
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left pane: the timer.
          Positioned(
            left: 0,
            top: 0,
            width: 640,
            height: 800,
            child: Center(
              child: BreakEntrance(
                child: BreakCompletionPulse(
                  complete: complete,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BreakProgressRing(
                        size: 220,
                        strokeWidth: 3,
                        progress: progress,
                        color: accent,
                        trackColor: palette.track,
                        flash: complete ? 0.5 : 0,
                        child: BreakCountdown(
                          seconds: widget.remainingSeconds,
                          color: breakClockColor(widget.settings, palette),
                        ),
                      ),
                      const SizedBox(height: 28),
                      BreakLabel(_kind.label),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Divider with a soft accent glow.
          Positioned(
            left: 639,
            top: 80,
            bottom: 80,
            width: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    accent.withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Right pane: the guidance carousel.
          Positioned(
            left: 640 + 64,
            right: 64,
            top: 0,
            height: 800,
            child: MouseRegion(
              onEnter: (_) => _hovering = true,
              onExit: (_) => _hovering = false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (items.isNotEmpty)
                      Semantics(
                        liveRegion: _manual,
                        child: AnimatedSwitcher(
                          duration: BreakMotion.medium,
                          switchInCurve: BreakMotion.enter,
                          transitionBuilder: (child, anim) {
                            final dx = reduced ? 0.0 : 12 / 512;
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: Offset(dx, 0),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, ?current],
                          ),
                          child: Column(
                            key: ValueKey(index),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[index].title,
                                style: BreakOverlayTheme.title.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              BreakTip(
                                items[index].body,
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (items.length > 1) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            _Dot(
                              active: i == index,
                              accent: accent,
                              muted: palette.track,
                              label: 'Show ${items[i].title}',
                              onTap: () => setState(() {
                                _index = i;
                                _manual = true;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ],
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

class _Dot extends StatelessWidget {
  final bool active;
  final Color accent;
  final Color muted;
  final String label;
  final VoidCallback onTap;

  const _Dot({
    required this.active,
    required this.accent,
    required this.muted,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // 6px dot inside a 24px touch target.
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: AnimatedContainer(
                duration: BreakMotion.fast,
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? accent : muted,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
