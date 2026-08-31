import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PrivacySection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const PrivacySection({super.key, required this.settings, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Privacy Report',
          subtitle:
              'Your data is yours. Learn how BreakMate protects your privacy.',
        ),
        const SizedBox(height: 16),

        buildCard([
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local-Only Storage',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'All your settings, break history, and productivity stats are stored locally on this machine using ObjectBox. We do not have servers and we do not collect your personal data.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          divider(),
          _settingsInfoTile(
            context,
            title: 'Native Integrations',
            subtitle:
                'Meeting detection and active app tracking run entirely on your OS. We only check for specific keywords locally to suggest relevant breaks.',
            icon: LucideIcons.cpu,
          ),
          divider(),
          _settingsInfoTile(
            context,
            title: 'Calendar Access',
            subtitle:
                'If enabled, we only read event start/end times to avoid interrupting your work. Event titles and details are never processed or saved.',
            icon: LucideIcons.calendar,
          ),
        ]),

        const SizedBox(height: 24),
        buildCard([
          toggleRow(
            'Track App Usage',
            'See which apps you use most, right on the Statistics screen. '
                'Only app names and time spent are stored, locally — never window titles or URLs.',
            settings.appUsageTrackingEnabled,
            (value) => onSave(settings.copyWith(appUsageTrackingEnabled: value)),
          ),
        ]),

        const SizedBox(height: 24),
        buildCard([
          actionRow(
            label: 'Delete All Local Data',
            subtitle:
                'This will reset all settings and wipe your statistics history. This cannot be undone.',
            buttonText: 'Wipe Data',
            onPressed: () {},
            isDestructive: true,
          ),
        ]),
      ],
    );
  }

  Widget _settingsInfoTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
