import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';

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

  // Native system-notification reminders were unreliable in practice, so
  // reminders always show the (dismissable, low-opacity) overlay now — see
  // `_handleHealthReminder` in timer_orchestrator.dart for the same choice
  // on the real, non-preview path.
  void _showPreview(String reminderType) {
    // `type` (above) only picks the native window's behavior — the Dart
    // overlay itself reads `overlayType` from the JSON payload to decide
    // which widget to render, and defaults to the full break-timer
    // template ('breakScreen') when that key is missing. Without this,
    // "Preview" was silently showing the wrong overlay entirely.
    sl<OverlayWindowService>().showOverlay(
      type: OverlayType.quickReminder,
      reminderType: reminderType,
      isPreview: true,
      // A brief reminder only needs to appear on the active display —
      // spinning up a full Flutter engine per connected monitor for a
      // 2-second poster is wasted CPU, more so on multi-monitor setups.
      showOnAllDisplays: false,
      builder: (context) => const SizedBox(),
      overlayData: {
        'overlayType': 'quickReminder',
        'reminderType': reminderType,
        'durationSeconds': 2,
        'remainingSeconds': 2,
        // Previewing is an explicit, in-the-moment action from Settings —
        // always show the real full-screen poster design, not the
        // meeting-safe fallback pill.
        'allowFullPoster': true,
      },
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (sl<OverlayWindowService>().currentOverlayType ==
          OverlayType.quickReminder) {
        sl<OverlayWindowService>().hideOverlay();
      }
    });
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
            onIntervalChanged: (v) =>
                onSave(settings.copyWith(postureReminderIntervalMinutes: v)),
            onPreview: () => _showPreview('posture'),
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
            onIntervalChanged: (v) =>
                onSave(settings.copyWith(eyeBlinkReminderIntervalMinutes: v)),
            onPreview: () => _showPreview('eye'),
          ),
        ],
      ],
    );
  }

  Widget _buildReminderOptions({
    required int interval,
    required ValueChanged<int> onIntervalChanged,
    required VoidCallback onPreview,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Interval',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          AppDropdown<int>(
            value: [10, 20, 30, 45, 60].contains(interval) ? interval : 30,
            items: [
              10,
              20,
              30,
              45,
              60,
            ].map((v) => AppDropdownItem(value: v, label: '$v min')).toList(),
            onChanged: (v) {
              if (v != null) onIntervalChanged(v);
            },
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onPreview,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.play_fill,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
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
