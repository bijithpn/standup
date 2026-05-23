import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/widgets/settings_widgets.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/shared/widgets/app_dropdown.dart';

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
        const SizedBox(height: 24),
        sectionHeader('Health Reminders'),
        buildCard([
          _buildPostureReminder(),
          divider(),
          _buildEyeBlinkReminder(),
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

  void _showPreview(String displayType, String reminderType) {
    if (displayType == 'native') {
      if (reminderType == 'posture') {
        sl<NotificationService>().showPostureReminder();
      } else {
        sl<NotificationService>().showEyeRestReminder();
      }
    } else {
      sl<OverlayWindowService>().showOverlay(
        type: OverlayType.quickReminder,
        reminderType: reminderType,
        builder: (context) => const SizedBox(),
      );
    }
  }

  Widget _buildPostureReminder() {
    return Column(
      children: [
        toggleRow(
          'Posture Correction',
          'Remind you to sit up straight and check your posture',
          settings.postureReminderEnabled,
          (v) => onSave(settings.copyWith(postureReminderEnabled: v)),
        ),
        if (settings.postureReminderEnabled) ...[
          divider(),
          _buildReminderOptions(
            interval: settings.postureReminderIntervalMinutes,
            type: settings.postureReminderType,
            onIntervalChanged: (v) => onSave(settings.copyWith(postureReminderIntervalMinutes: v)),
            onTypeChanged: (v) => onSave(settings.copyWith(postureReminderType: v)),
            onPreview: () => _showPreview(settings.postureReminderType, 'posture'),
          ),
        ],
      ],
    );
  }

  Widget _buildEyeBlinkReminder() {
    return Column(
      children: [
        toggleRow(
          'Eye Rest & Blinking',
          'Remind you to look away and blink your eyes',
          settings.eyeBlinkReminderEnabled,
          (v) => onSave(settings.copyWith(eyeBlinkReminderEnabled: v)),
        ),
        if (settings.eyeBlinkReminderEnabled) ...[
          divider(),
          _buildReminderOptions(
            interval: settings.eyeBlinkReminderIntervalMinutes,
            type: settings.eyeBlinkReminderType,
            onIntervalChanged: (v) => onSave(settings.copyWith(eyeBlinkReminderIntervalMinutes: v)),
            onTypeChanged: (v) => onSave(settings.copyWith(eyeBlinkReminderType: v)),
            onPreview: () => _showPreview(settings.eyeBlinkReminderType, 'eye'),
          ),
        ],
      ],
    );
  }

  Widget _buildReminderOptions({
    required int interval,
    required String type,
    required ValueChanged<int> onIntervalChanged,
    required ValueChanged<String> onTypeChanged,
    required VoidCallback onPreview,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Text('Interval & Display', style: TextStyle(color: Colors.white70, fontSize: 13))),
          AppDropdown<int>(
            value: [10, 20, 30, 45, 60].contains(interval) ? interval : 30,
            items: [10, 20, 30, 45, 60].map((v) => AppDropdownItem(value: v, label: '$v min')).toList(),
            onChanged: (v) { if (v != null) onIntervalChanged(v); },
          ),
          const SizedBox(width: 8),
          AppDropdown<String>(
            value: ['native', 'overlay'].contains(type) ? type : 'overlay',
            items: const [
              AppDropdownItem(value: 'native', label: 'Native'),
              AppDropdownItem(value: 'overlay', label: 'Overlay'),
            ],
            onChanged: (v) { if (v != null) onTypeChanged(v); },
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onPreview,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.play_fill, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Preview', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
