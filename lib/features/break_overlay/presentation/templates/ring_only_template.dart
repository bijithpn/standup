import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class RingOnlyTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const RingOnlyTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<RingOnlyTemplate> createState() => _RingOnlyTemplateState();
}

class _RingOnlyTemplateState extends State<RingOnlyTemplate> {
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  bool get _complete => widget.remainingSeconds <= 0 && widget.totalSeconds > 0;

  @override
  void didUpdateWidget(covariant RingOnlyTemplate old) {
    super.didUpdateWidget(old);
    final wasComplete = old.remainingSeconds <= 0 && old.totalSeconds > 0;
    if (_complete && !wasComplete) {
      // Quiet tactile cue where the platform supports it.
      HapticFeedback.lightImpact().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = breakAccent(
      widget.settings,
      'ring_only',
      BreakOverlayTheme.periwinkle,
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            left: 640 - 120,
            top: 400 - 120,
            child: BreakEntrance(
              child: Semantics(
                label: '${_kind.label}, ${(progress * 100).round()} percent',
                child: TweenAnimationBuilder<double>(
                  // Completion: the ring flashes to full alpha with a glow.
                  tween: Tween(end: _complete ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (context, flash, child) => BreakProgressRing(
                    size: 240,
                    strokeWidth: 1.5,
                    progress: progress,
                    color: accent.withValues(alpha: 0.7 + 0.3 * flash),
                    trackColor: palette.isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFF1C1F24).withValues(alpha: 0.10),
                    taperDegrees: 12,
                    taperTo: 4,
                    flash: flash * 0.8,
                    child: child,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          _kind.icon,
                          size: 18,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      BreakCountdown(
                        seconds: widget.remainingSeconds,
                        color: breakClockColor(widget.settings, palette),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
