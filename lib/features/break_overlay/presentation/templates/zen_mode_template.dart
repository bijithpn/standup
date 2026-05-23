import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/shared/theme/app_theme.dart';

class ZenModeTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ZenModeTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ZenModeTemplate> createState() => _ZenModeTemplateState();
}

class _ZenModeTemplateState extends State<ZenModeTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;

  final List<String> _zenQuotes = [
    'Silence is not silent. It is full of answers.',
    'Breathe in experience, breathe out poetry.',
    'Concentrate the mind on the present moment.',
    'Within you, there is a sanctuary of peace.',
    'Flow with whatever may happen.',
    'Mindfulness is remembering to be present.',
  ];

  late String _activeQuote;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _activeQuote = _zenQuotes[DateTime.now().minute % _zenQuotes.length];
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.gray950,
      child: Stack(
        children: [
          // Subtle gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    AppTheme.longBreak.withValues(alpha: 0.02),
                    AppTheme.gray950,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.longBreak.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: AppTheme.longBreak.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.wind,
                        size: 12,
                        color: AppTheme.longBreak,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ZEN MODE',
                        style: TextStyle(
                          color: AppTheme.longBreak,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 64),

                // Breathing circle
                AnimatedBuilder(
                  animation: _breathingController,
                  builder: (context, child) {
                    final val = _breathingController.value;
                    double scale = 0.5;
                    String text = 'Breathe In';

                    if (val < 0.25) {
                      final t = val / 0.25;
                      scale = 0.5 + (t * 0.5);
                      text = 'Breathe In';
                    } else if (val < 0.5) {
                      scale = 1.0;
                      text = 'Hold';
                    } else if (val < 0.75) {
                      final t = (val - 0.5) / 0.25;
                      scale = 1.0 - (t * 0.5);
                      text = 'Breathe Out';
                    } else {
                      scale = 0.5;
                      text = 'Hold';
                    }

                    return Column(
                      children: [
                        SizedBox(
                          width: 280,
                          height: 280,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer ring
                              Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.gray800,
                                    width: 1,
                                  ),
                                ),
                              ),
                              // Breathing circle
                              Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 260,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.longBreak.withValues(
                                      alpha: 0.05,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.longBreak.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              // Text
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTime(widget.remainingSeconds),
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 48),

                // Quote
                Container(
                  width: 480,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.gray900,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.quote,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activeQuote,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Skip button
          if (widget.onSkip != null)
            Positioned(
              right: 32,
              bottom: 32,
              child: MouseRegion(
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
            ),
        ],
      ),
    );
  }
}
