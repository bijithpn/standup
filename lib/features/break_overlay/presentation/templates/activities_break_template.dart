import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/guided_breathing_widget.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/eye_sync_game_widget.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';

enum _BreakActivity { breathing, eyeSync }

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
  late Key _activityKey;

  @override
  void initState() {
    super.initState();
    _selectedActivity = widget.breakInfo.type == BreakType.short
        ? _BreakActivity.eyeSync
        : _BreakActivity.breathing;
    _activityKey = UniqueKey();
  }

  void _switchActivity(_BreakActivity activity) {
    if (activity == _selectedActivity) return;
    setState(() {
      _selectedActivity = activity;
      _activityKey = UniqueKey();
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _selectedActivity == _BreakActivity.breathing
        ? const Color(0xFF38BDF8) // Breath Blue
        : const Color(0xFF34D399); // Eye Sync Green
    final media = MediaQuery.of(context).size;
    final compact = media.width < 760;

    return Material(
      color: const Color(0xFF07080B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: _ActivitiesBackdrop(activity: _selectedActivity),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(compact ? 24 : 36),
              child: Column(
                children: [
                  _TopBar(
                    breakInfo: widget.breakInfo,
                    remainingSeconds: widget.remainingSeconds,
                    totalSeconds: widget.totalSeconds,
                    formatTime: _formatTime,
                  ),
                  const SizedBox(height: 32),
                  _ActivitySelector(
                    selected: _selectedActivity,
                    onSelect: _switchActivity,
                    accent: accent,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 680),
                        padding: EdgeInsets.all(compact ? 16 : 28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.025),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.03),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: _buildActivityPanel(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!widget.settings.strictMode && widget.onSkip != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: SkipBreakButton(onSkip: widget.onSkip!),
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

class _TopBar extends StatelessWidget {
  final BreakModel breakInfo;
  final int remainingSeconds;
  final int totalSeconds;
  final String Function(int) formatTime;

  const _TopBar({
    required this.breakInfo,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final isShort = breakInfo.type == BreakType.short;
    final accentColor = isShort
        ? const Color(0xFF38BDF8)
        : const Color(0xFF34D399);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accentColor.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isShort ? LucideIcons.zap : LucideIcons.coffee,
                size: 11,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                '${isShort ? 'QUICK' : 'LONG'} BREAK · ${totalSeconds < 60 ? '${totalSeconds}s' : '${totalSeconds ~/ 60}m'}',
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Text(
            formatTime(remainingSeconds),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
  final Color accent;

  const _ActivitySelector({
    required this.selected,
    required this.onSelect,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActivityTab(
            icon: LucideIcons.wind,
            label: 'Breathing',
            isSelected: selected == _BreakActivity.breathing,
            activeColor: const Color(0xFF38BDF8),
            onTap: () => onSelect(_BreakActivity.breathing),
          ),
          const SizedBox(width: 4),
          _ActivityTab(
            icon: LucideIcons.eye,
            label: 'Eye Sync',
            isSelected: selected == _BreakActivity.eyeSync,
            activeColor: const Color(0xFF34D399),
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
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.24)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
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

class _ActivitiesBackdrop extends StatelessWidget {
  final _BreakActivity activity;
  const _ActivitiesBackdrop({required this.activity});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ActivitiesBackdropPainter(activity: activity));
  }
}

class _ActivitiesBackdropPainter extends CustomPainter {
  final _BreakActivity activity;
  _ActivitiesBackdropPainter({required this.activity});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF08090C),
    );

    final Color glowColor = activity == _BreakActivity.breathing
        ? const Color(0xFF0284C7) // Breathe Blue
        : const Color(0xFF059669); // Eye Green

    // Ambient radial glow background spot
    final center = Offset(size.width * 0.5, size.height * 0.4);
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [glowColor.withValues(alpha: 0.06), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.6),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);

    // Fine decorative dot grid
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.03);
    const double gap = 48.0;
    for (double x = gap; x < size.width; x += gap) {
      for (double y = gap; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActivitiesBackdropPainter oldDelegate) =>
      oldDelegate.activity != activity;
}
