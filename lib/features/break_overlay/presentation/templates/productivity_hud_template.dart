import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/shared/theme/app_theme.dart';

class ProductivityHudTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ProductivityHudTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ProductivityHudTemplate> createState() =>
      _ProductivityHudTemplateState();
}

class _ProductivityHudTemplateState extends State<ProductivityHudTemplate> {
  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalSeconds > 0
        ? 1 - (widget.remainingSeconds / widget.totalSeconds)
        : 0.0;

    final isShortBreak = widget.breakInfo.type == BreakType.short;
    final accentColor = isShortBreak ? AppTheme.shortBreak : AppTheme.longBreak;

    return Material(
      color: AppTheme.gray950,
      child: Stack(
        children: [
          // Grid pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.02,
              child: GridPaper(
                color: Colors.white,
                interval: 100,
                divisions: 1,
                subdivisions: 1,
              ),
            ),
          ),

          // Main HUD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Break type
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isShortBreak ? LucideIcons.eye : LucideIcons.coffee,
                              size: 12,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isShortBreak ? 'EYE REST' : 'BREAK',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Current time
                      Text(
                        DateFormat('HH:mm').format(DateTime.now()),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Center content
                  Column(
                    children: [
                      // Timer
                      Text(
                        _formatTime(widget.remainingSeconds),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 72,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Progress bar
                      Container(
                        width: 400,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.gray800,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        isShortBreak ? 'Rest Your Eyes' : 'Take a Break',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tip
                      SizedBox(
                        width: 500,
                        child: Text(
                          widget.breakInfo.tip,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Bottom bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Stats
                      Row(
                        children: [
                          _buildStat(
                            icon: LucideIcons.target,
                            label: 'Focus',
                            value: '${(progress * 100).toInt()}%',
                          ),
                          const SizedBox(width: 24),
                          _buildStat(
                            icon: LucideIcons.zap,
                            label: 'Energy',
                            value: 'High',
                          ),
                        ],
                      ),

                      // Skip button
                      if (widget.onSkip != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onSkip,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.gray800,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Skip',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    LucideIcons.chevronRight,
                                    size: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.textMuted,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
