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
            _StatusRow(
              title: AppStrings.companion,
              subtitle: companionActive
                  ? (controller.timerEngine.state == TimerState.running
                        ? 'Active and watching'
                        : 'Resting')
                  : 'Disabled in settings',
              value: companionActive,
              onChanged: controller.toggleCompanion,
              semanticsLabel: 'Toggle desktop companion',
            ),
            Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
            _StatusRow(
              title: AppStrings.quietMode,
              subtitle: controller.quietModeEnabled
                  ? 'All alerts silenced'
                  : 'Notifications on',
              value: controller.quietModeEnabled,
              onChanged: controller.toggleQuietMode,
              semanticsLabel: 'Toggle quiet mode',
            ),
          ],
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onChanged;
  final String semanticsLabel;

  const _StatusRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: '   $subtitle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            label: semanticsLabel,
            child: Switch(value: value, onChanged: (_) => onChanged()),
          ),
        ],
      ),
    );
  }
}
