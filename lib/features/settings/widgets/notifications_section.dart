import 'package:flutter/cupertino.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/widgets/settings_widgets.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';

class NotificationsSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const NotificationsSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Notifications'),
        buildCard([
          _buildSoundEnabled(),
          divider(),
          _buildNotificationsEnabled(),
        ]),

      ],
    );
  }

  Widget _buildSoundEnabled() {
    return toggleRow(
      'Sound',
      'Play sound notifications for breaks',
      settings.soundEnabled,
      (v) {
        onSave(settings.copyWith(soundEnabled: v));
        sl<TrayManagerService>().triggerActionAnimation();
      },
    );
  }

  Widget _buildNotificationsEnabled() {
    return toggleRow(
      'System Notifications',
      'Show system notifications for breaks',
      settings.notificationsEnabled,
      (v) {
        onSave(settings.copyWith(notificationsEnabled: v));
        sl<TrayManagerService>().triggerActionAnimation();
      },
    );
  }

}
