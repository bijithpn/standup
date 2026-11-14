import 'settings_group.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
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
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          selectedTileColor: AppTheme.selectedSurface,
          title: Text(
            preset.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            preset.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          leading: Icon(
            preset.matches(settings)
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: preset.matches(settings)
                ? AppTheme.accent
                : AppTheme.textMuted,
          ),
          selected: preset.matches(settings),
          onTap: () => onChanged(preset.apply(settings)),
        ),
      if (!NotificationIntensity.values.any(
        (preset) => preset.matches(settings),
      ))
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Custom settings — choose a preset to replace your warning, sound and display options.',
          ),
        ),
    ],
  );
}
