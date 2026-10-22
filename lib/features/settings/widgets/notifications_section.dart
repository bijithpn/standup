import 'dart:math';

import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';

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
          toggleRow(
            'Health reminders',
            'Gentle nudges for your eyes, posture, water, stretching and '
                'standing up — shown one at a time, at varied moments.',
            settings.healthRemindersEnabled,
            (v) => onSave(settings.copyWith(healthRemindersEnabled: v)),
          ),
          if (settings.healthRemindersEnabled) ...[
            divider(),
            _buildReminderPreviewRow(onPreview: _previewRandom),
          ],
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Which reminder appears is random and follows how you work: the '
            'more you have worked today, the more often they come; light days '
            'get fewer. They hold back during meetings, right around breaks, '
            'and after you step away. At most 4 per hour (5 on very busy '
            'days), and ones you keep ignoring are spaced further apart.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
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
  void _previewRandom() {
    const types = ['eyeblink', 'posture', 'hydration', 'stretch', 'standup'];
    _showPreview(types[Random().nextInt(types.length)]);
  }

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

  // No manual interval anymore — timing is automatic, tied to the actual
  // break cycle (see `TimerEngine._checkHealthReminders`) rather than a
  // separately configured countdown. Enable/disable above is the only
  // control; this row is just the explanation + a way to preview the look.
  Widget _buildReminderPreviewRow({required VoidCallback onPreview}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Preview a random reminder',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
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
