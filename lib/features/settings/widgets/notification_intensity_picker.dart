import 'settings_group.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../settings_model.dart';
import '../notification_intensity.dart';

class NotificationIntensityPicker extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onChanged;
  const NotificationIntensityPicker({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SettingsGroup(
    children: [
      for (final preset in NotificationIntensity.values)
        Semantics(
          button: true,
          selected: preset.matches(settings),
          child: InkWell(
            onTap: () => onChanged(preset.apply(settings)),
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
                            preset.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preset.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (preset.matches(settings))
                      Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 18,
                        color: AppTheme.accentColor,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (!NotificationIntensity.values.any(
        (preset) => preset.matches(settings),
      ))
        const SettingsNote(
          'Custom settings. Choose a preset to replace your warning, sound and display options.',
        ),
    ],
  );
}
