import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

import 'motion_kit.dart';
import 'wellness_models.dart';

/// One of the six templates. Implementations are const, stateless factories;
/// painters read time from the [MotionClock] and progress from the
/// [BreakSession] so nothing here owns a timer.
abstract class WellnessTemplate {
  const WellnessTemplate();

  String get id;
  String get name;
  String get description;

  /// Fixed identity palette (never randomised).
  BreakPalette get palette;

  /// Full-screen composition including its own countdown typography.
  Widget immersive(BuildContext context, BreakSession s, MotionClock clock);

  /// Artwork only, designed for roughly 320x96 up to 120x120 regions
  /// (use LayoutBuilder). Not a scaled-down immersive view.
  Widget compactArt(BuildContext context, BreakSession s, MotionClock clock);

  /// Tiny (about 40x40) mark for standalone reminders.
  Widget reminderArt(
    BuildContext context,
    ReminderKind kind,
    MotionClock clock,
  );

  /// Static preview frame for gallery cards; never animates.
  Widget preview(BuildContext context, {required bool compact}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final s = BreakSession(
      totalSeconds: 300,
      remainingSeconds: 195,
      targetEndMs: null,
      startedAtMs: now - 40000,
      tier: MotionTier.still,
    );
    return MotionScope(
      startedAtMs: s.startedAtMs,
      tier: MotionTier.still,
      builder: (c, clock) =>
          compact ? compactArt(c, s, clock) : immersive(c, s, clock),
    );
  }
}

String formatRemaining(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

/// Spoken form for screen readers: "1 minute 45 seconds remaining".
String spokenRemaining(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  return [
    if (m > 0) '$m ${m == 1 ? 'minute' : 'minutes'}',
    if (s > 0 || m == 0) '$s ${s == 1 ? 'second' : 'seconds'}',
  ].join(' ');
}

/// Shared compact break surface (about 340x210): template art, remaining
/// time, one instruction, minimal actions.
class CompactBreakCard extends StatelessWidget {
  const CompactBreakCard({
    super.key,
    required this.template,
    required this.session,
    required this.clock,
    this.onSkip,
    this.onOpenImmersive,
  });

  final WellnessTemplate template;
  final BreakSession session;
  final MotionClock clock;
  final VoidCallback? onSkip;
  final VoidCallback? onOpenImmersive;

  @override
  Widget build(BuildContext context) {
    final p = template.palette;
    final canSkip = !session.strictMode && onSkip != null;
    final mono = BreakOverlayTheme.monoFamily;
    return Semantics(
      container: true,
      label:
          '${session.title}. ${spokenRemaining(session.remainingSeconds)} remaining',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.canvas,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: ExcludeSemantics(
                      child: template.compactArt(context, session, clock),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontFamily: BreakOverlayTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: p.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatRemaining(session.remainingSeconds),
                      style: TextStyle(
                        fontFamily: mono,
                        fontSize: 15,
                        color: p.textSecondary,
                        fontFeatures: BreakOverlayTheme.tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session.instruction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: BreakOverlayTheme.fontFamily,
                    fontSize: 13,
                    height: 1.4,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onOpenImmersive != null)
                      _CardAction('Open full view', onOpenImmersive!, p),
                    if (canSkip) _CardAction('Skip', onSkip!, p),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction(this.label, this.onTap, this.p);
  final String label;
  final VoidCallback onTap;
  final BreakPalette p;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: p.textSecondary,
      minimumSize: const Size(48, 32),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(
        fontFamily: BreakOverlayTheme.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    child: Text(label),
  );
}
