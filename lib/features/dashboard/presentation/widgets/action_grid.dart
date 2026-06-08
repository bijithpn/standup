import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final companionActive = controller.companionEnabled;

        return Row(
          children: [
            Expanded(
              child: _ActionCard(
                title: AppStrings.companion,
                subtitle: companionActive
                    ? (controller.timerEngine.state == TimerState.running
                          ? 'Active and watching'
                          : 'Resting')
                    : 'Disabled in settings',
                icon: Icons.pets_rounded,
                isActive: companionActive,
                onTap: () => controller.toggleCompanion(),
                semanticsLabel: 'Toggle desktop companion',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(
                title: AppStrings.quietMode,
                subtitle: controller.quietModeEnabled
                    ? 'All alerts silenced'
                    : 'Notifications on',
                icon: Icons.do_not_disturb_on_rounded,
                isActive: controller.quietModeEnabled,
                onTap: () => controller.toggleQuietMode(),
                semanticsLabel: 'Toggle quiet mode',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final String? semanticsLabel;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isActive = true,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? '$title: $subtitle',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.accent.withValues(alpha: 0.1)
                      : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isActive ? AppTheme.accent : AppTheme.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
