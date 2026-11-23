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
        sectionHeader('Presets'),
        buildCard([
          for (final p in BreakProfile.presets)
            Semantics(
              button: true,
              selected: settings.selectedProfileId == p.id,
              child: InkWell(
                onTap: () {
                  Provider.of<BreakController>(
                    context,
                    listen: false,
                  ).changeProfile(p);
                  onSave(settings.copyWith(selectedProfileId: p.id));
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Every ${p.shortIntervalMinutes} min · ${p.shortDurationSeconds} s',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontFeatures: AppTheme.tabular,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (settings.selectedProfileId == p.id)
                          Icon(
                            CupertinoIcons.checkmark_alt,
                            color: AppTheme.accentColor,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ],
    );
  }
}
