import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/guided_breathing_widget.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/eye_sync_game_widget.dart';

// ── Activity enum ─────────────────────────────────────────────────────────────

enum _BreakActivity { breathing, eyeSync }

// ── Template ──────────────────────────────────────────────────────────────────

/// Full-screen break overlay with two selectable guided activities:
///   🌬 Guided Breathing (4-7-8 technique)
///   👁  Eye Sync (20-20-20 rule)
class ActivitiesBreakTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ActivitiesBreakTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ActivitiesBreakTemplate> createState() =>
      _ActivitiesBreakTemplateState();
}

class _ActivitiesBreakTemplateState extends State<ActivitiesBreakTemplate>
    with SingleTickerProviderStateMixin {
  late _BreakActivity _selectedActivity;

  // Activity widgets have internal timers; we give each a unique key so they
  // rebuild completely when the user switches activities.
  late Key _activityKey;

  @override
  void initState() {
    super.initState();
    // Default selection based on break type
    _selectedActivity = widget.breakInfo.type == BreakType.short
        ? _BreakActivity.eyeSync
        : _BreakActivity.breathing;
    _activityKey = UniqueKey();
  }

  void _switchActivity(_BreakActivity activity) {
    if (activity == _selectedActivity) return;
    setState(() {
      _selectedActivity = activity;
      _activityKey = UniqueKey(); // Reset the activity widget
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF070A0D),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Static background
          const RepaintBoundary(child: _ActivitiesBackdrop()),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // ── Top bar ───────────────────────────────────────────────
                  _TopBar(
                    breakInfo: widget.breakInfo,
                    remainingSeconds: widget.remainingSeconds,
                    formatTime: _formatTime,
                  ),
                  const SizedBox(height: 36),

                  // ── Activity selector tabs ────────────────────────────────
                  _ActivitySelector(
                    selected: _selectedActivity,
                    onSelect: _switchActivity,
                  ),
                  const SizedBox(height: 40),

                  // ── Activity panel ────────────────────────────────────────
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _buildActivityPanel(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Bottom rail ───────────────────────────────────────────
                  _BottomRail(
                    strictMode: widget.settings.strictMode,
                    onSkip: widget.onSkip,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPanel() {
    switch (_selectedActivity) {
      case _BreakActivity.breathing:
        return GuidedBreathingWidget(
          key: _activityKey,
          targetCycles: widget.breakInfo.type == BreakType.short ? 2 : 4,
        );
      case _BreakActivity.eyeSync:
        return EyeSyncGameWidget(
          key: _activityKey,
          targetSessions: widget.breakInfo.type == BreakType.short ? 2 : 3,
        );
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final BreakModel breakInfo;
  final int remainingSeconds;
  final String Function(int) formatTime;

  const _TopBar({
    required this.breakInfo,
    required this.remainingSeconds,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final isShort = breakInfo.type == BreakType.short;
    final accentColor = isShort
        ? const Color(0xFF38BDF8)
        : const Color(0xFF7DD3FC);

    return Row(
      children: [
        // Break type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accentColor.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isShort ? LucideIcons.zap : LucideIcons.coffee,
                size: 11,
                color: accentColor,
              ),
              const SizedBox(width: 5),
              Text(
                isShort ? 'QUICK BREAK' : 'LONG BREAK',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Countdown
        RepaintBoundary(
          child: Text(
            formatTime(remainingSeconds),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivitySelector extends StatelessWidget {
  final _BreakActivity selected;
  final void Function(_BreakActivity) onSelect;

  const _ActivitySelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActivityTab(
            icon: LucideIcons.wind,
            label: 'Breathing',
            isSelected: selected == _BreakActivity.breathing,
            activeColor: const Color(0xFF7DD3FC),
            onTap: () => onSelect(_BreakActivity.breathing),
          ),
          const SizedBox(width: 4),
          _ActivityTab(
            icon: LucideIcons.eye,
            label: 'Eye Sync',
            isSelected: selected == _BreakActivity.eyeSync,
            activeColor: const Color(0xFF38BDF8),
            onTap: () => onSelect(_BreakActivity.eyeSync),
          ),
        ],
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActivityTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: isSelected
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.3))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomRail extends StatelessWidget {
  final bool strictMode;
  final VoidCallback? onSkip;

  const _BottomRail({required this.strictMode, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!strictMode && onSkip != null)
          GestureDetector(
            onTap: onSkip,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Static backdrop ───────────────────────────────────────────────────────────

class _ActivitiesBackdrop extends StatelessWidget {
  const _ActivitiesBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ActivitiesBackdropPainter());
  }
}

class _ActivitiesBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark base
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF070A0D),
    );

    // Subtle dot grid
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.04);
    const gap = 48.0;
    for (double x = gap; x < size.width; x += gap) {
      for (double y = gap; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // Soft center radial glow
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF0EA5E9).withValues(alpha: 0.07),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.45),
              radius: size.shortestSide * 0.55,
            ),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
