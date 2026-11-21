import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/settings/break_profile.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';

class BreakProfileSelector extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const BreakProfileSelector({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Recommended presets',
          subtitle: 'Choose a scientifically-backed rhythm for your work day.',
        ),
        buildCard(
          BreakProfile.presets.map((p) {
            final isSelected = settings.selectedProfileId == p.id;
            return Column(
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () {
                      Provider.of<BreakController>(
                        context,
                        listen: false,
                      ).changeProfile(p);
                      onSave(settings.copyWith(selectedProfileId: p.id));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentColor.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? CupertinoIcons.checkmark_alt
                                : _getProfileIcon(p.id),
                            color: isSelected
                                ? AppTheme.accentColor
                                : AppTheme.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: isSelected
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Every ${p.shortIntervalMinutes} min · ${p.shortDurationSeconds} s',
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppTheme.textSecondary
                                        : AppTheme.textMuted,
                                    fontSize: 12,
                                    fontFeatures: AppTheme.tabular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (p != BreakProfile.presets.last) divider(),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getProfileIcon(String id) {
    switch (id) {
      case 'balanced':
        return CupertinoIcons.infinite;
      case 'deep_work':
        return CupertinoIcons.flame;
      case 'pomodoro':
        return CupertinoIcons.timer;
      default:
        return CupertinoIcons.layers;
    }
  }
}
