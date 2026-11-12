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

        return Column(
          children: [
            _ActionCard(
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
            _ActionCard(
              title: AppStrings.quietMode,
              subtitle: controller.quietModeEnabled
                  ? 'All alerts silenced'
                  : 'Notifications on',
              icon: Icons.do_not_disturb_on_rounded,
              isActive: controller.quietModeEnabled,
              onTap: () => controller.toggleQuietMode(),
              semanticsLabel: 'Toggle quiet mode',
            ),
            Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
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
        child: Column(
          children: [
            Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isActive ? 'On' : 'Off',
                    style: TextStyle(
                      fontFamilyFallback: const ['Menlo', 'monospace'],
                      fontSize: 12,
                      color: isActive ? AppTheme.success : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
