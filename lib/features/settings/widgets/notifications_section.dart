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
        const SizedBox(height: 48),
        sectionHeader('Flash Reminder'),
        const SizedBox(height: 24),
        buildCard([
          _buildFlashStyle(),
          divider(),
          _buildFlashMessage(),
          divider(),
          _buildFlashAnimation(),
          divider(),
          _buildFlashIntensity(),
          divider(),
          _buildFlashDuration(context),
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

  Widget _buildFlashStyle() {
    return buildListRow(
      'Flash Style',
      'Visual reminder style',
      null,
      CupertinoIcons.bolt_fill,
      null,
      trailing: inlineDropdown(
        settings.flashStyle,
        ['default', 'gradient', 'solid', 'pulse'],
        (v) {
          onSave(settings.copyWith(flashStyle: v ?? 'default'));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }

  Widget _buildFlashMessage() {
    return textFieldRow(
      'Flash Message',
      settings.flashMessage,
      (v) => onSave(settings.copyWith(flashMessage: v)),
    );
  }

  Widget _buildFlashAnimation() {
    return buildListRow(
      'Flash Animation',
      'Animation type for flash reminder',
      null,
      CupertinoIcons.sparkles,
      null,
      trailing: inlineDropdown(
        settings.flashAnimationType,
        ['pulse', 'fade', 'slide', 'bounce'],
        (v) {
          onSave(settings.copyWith(flashAnimationType: v ?? 'pulse'));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }

  Widget _buildFlashIntensity() {
    return sliderRow(
      'Flash Intensity',
      settings.flashIntensity,
      (v) => onSave(settings.copyWith(flashIntensity: v)),
      min: 0.0,
      max: 1.0,
    );
  }

  Widget _buildFlashDuration(BuildContext context) {
    return inputRow(
      'Flash Duration',
      '${settings.flashDurationMs} ms',
      onTap: () => showPicker(
        context: context,
        title: 'Flash Duration',
        options: ['1000', '1500', '2000', '2500', '3000', '4000', '5000'],
        suffix: ' ms',
        onSelected: (v) {
          onSave(settings.copyWith(flashDurationMs: int.parse(v)));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }
}
