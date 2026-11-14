import 'settings_group.dart';
import 'advanced_settings.dart';
import 'notification_intensity_picker.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'dart:io';
import 'dart:math';

import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/analytics/time_pattern_insights.dart'
    show formatHourLabel;
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/health_reminder_messages.dart';
import 'package:breakmate/core/services/native_enhancements_service.dart';
import 'package:breakmate/core/constants/app_constants.dart';

/// Settings > Notifications: sounds, health reminders (eye, posture, hydration...) and user-defined custom reminders.
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
        sectionHeader('Reminder Intensity'),
        NotificationIntensityPicker(settings: settings, onChanged: onSave),
        const SizedBox(height: 8),
        sectionHeader('Notifications'),
        SettingsGroup(
          children: [_buildSoundEnabled(), _buildNotificationsEnabled()],
        ),
        const SizedBox(height: 8),
        sectionHeader('Health Reminders'),
        SettingsGroup(
          children: [
            toggleRow(
              'Health reminders',
              'Gentle nudges for your eyes, posture, water, stretching and '
                  'standing up — shown one at a time, at varied moments.',
              settings.healthRemindersEnabled,
              (v) => onSave(settings.copyWith(healthRemindersEnabled: v)),
            ),
            if (settings.healthRemindersEnabled) ...[
              _buildReminderPreviewRow(onPreview: _previewRandom),
              AdvancedSettings(
                title: 'More health reminder options',
                children: [
                  if (Platform.isMacOS) ...[
                    divider(),
                    toggleRow(
                      'Dismiss on mouse movement',
                      settings.dismissReminderOnMouseMove
                          ? 'On: moving the mouse dismisses new reminders after a brief pause.'
                          : 'Off: reminders stay visible for their full duration.',
                      settings.dismissReminderOnMouseMove,
                      (v) => onSave(
                        settings.copyWith(dismissReminderOnMouseMove: v),
                      ),
                    ),
                  ],
                  if (kDebugMode && Platform.isMacOS) ...[
                    divider(),
                    _buildReminderPreviewRow(
                      label: 'Preview posture reminder (debug)',
                      onPreview: () => _showPreview('posture'),
                    ),
                    divider(),
                    _buildReminderPreviewRow(
                      label: 'Preview water reminder (debug)',
                      onPreview: () => _showPreview('hydration'),
                    ),
                    divider(),
                    _buildReminderPreviewRow(
                      label: 'Preview notification toast (debug)',
                      onPreview: () =>
                          NativeEnhancementsService.instance.showToast(
                            title: 'Time for a break',
                            body: 'Eye Rest',
                            sound: settings.soundEnabled,
                          ),
                    ),
                  ],
                  divider(),
                  toggleRow(
                    'Blink & screen-distance reminders',
                    'An extra, more frequent nudge to blink fully and keep the '
                        'screen an arm\'s length away.',
                    settings.blinkRemindersEnabled,
                    (v) => onSave(settings.copyWith(blinkRemindersEnabled: v)),
                  ),
                ],
              ),
            ],
            AdvancedSettings(
              title: 'Focus and evening options',
              children: [
                if (settings.avoidBreakHour >= 0) ...[
                  divider(),
                  toggleRow(
                    'Avoid breaks around ${formatHourLabel(settings.avoidBreakHour)}',
                    'Breaks due in that hour wait until the next one. Turn off to '
                        'restore normal timing.',
                    true,
                    (_) => onSave(settings.copyWith(avoidBreakHour: -1)),
                  ),
                ],
                divider(),
                toggleRow(
                  'Do Not Disturb in focus sessions',
                  'macOS only. Create two Shortcuts named "BreakMate Focus On" and '
                      '"BreakMate Focus Off" that set your Focus mode.',
                  settings.focusDndEnabled,
                  (v) => onSave(settings.copyWith(focusDndEnabled: v)),
                ),
                divider(),
                toggleRow(
                  'Evening eye care',
                  'At 8 pm, turn on Night Shift (macOS) and nudge you to lower brightness.',
                  settings.eveningEyeCare,
                  (v) => onSave(settings.copyWith(eveningEyeCare: v)),
                ),
              ],
            ),
          ],
        ),
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
        const SizedBox(height: 8),
        AdvancedSettings(
          title: 'Custom reminders',
          subtitle: 'Add and manage your own recurring nudges',
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in settings.customReminders) ...[
                  ListTile(
                    dense: true,
                    title: Text(
                      r.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Every ${r.minutes} min',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: Icon(
                        CupertinoIcons.delete,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => onSave(
                        settings.copyWith(
                          customReminders: [...settings.customReminders]
                            ..remove(r),
                        ),
                      ),
                    ),
                  ),
                  divider(),
                ],
                _CustomReminderForm(
                  onAdd: (r) => onSave(
                    settings.copyWith(
                      customReminders: [...settings.customReminders, r],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSoundEnabled() {
    return toggleRow(
      'Sound',
      'Play sound notifications for breaks and a distinct tone for each reminder',
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

  void _previewRandom() {
    const types = ['eyeblink', 'posture', 'hydration', 'stretch', 'standup'];
    _showPreview(types[Random().nextInt(types.length)]);
  }

  void _showPreview(String reminderType) {
    if (Platform.isMacOS) {
      NativeEnhancementsService.instance.triggerFlashReminder(
        text: HealthReminderMessages.text(reminderType),
        reminderType: reminderType,
        durationMs: AppConstants.healthReminderDismissDuration.inMilliseconds,
        opacity: 0.2,
        dismissOnMouseMove: settings.dismissReminderOnMouseMove,
        textScale: settings.experience.textScale,
        highContrast: settings.experience.highContrast,
        reduceMotion: settings.reduceMotion || !settings.enableAnimations,
      );
      return;
    }

    sl<OverlayWindowService>().showOverlay(
      type: OverlayType.quickReminder,
      reminderType: reminderType,
      isPreview: true,

      showOnAllDisplays: false,
      builder: (context) => const SizedBox(),
      overlayData: {
        'overlayType': 'quickReminder',
        'reminderType': reminderType,
        'durationSeconds': 2,
        'remainingSeconds': 2,

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

  Widget _buildReminderPreviewRow({
    required VoidCallback onPreview,
    String label = 'Preview a random reminder',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          TapTarget(
            onTap: onPreview,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.play_fill,
                      size: 14,
                      color: AppTheme.textPrimary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Preview',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
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

// Adds a reminder only when the title is non-empty and interval is at least 1 minute.
class _CustomReminderForm extends StatefulWidget {
  final ValueChanged<CustomReminder> onAdd;
  const _CustomReminderForm({required this.onAdd});

  @override
  State<_CustomReminderForm> createState() => _CustomReminderFormState();
}

class _CustomReminderFormState extends State<_CustomReminderForm> {
  final _title = TextEditingController();
  final _minutes = TextEditingController(text: '60');
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _add() {
    final title = _title.text.trim();
    final minutes = int.tryParse(_minutes.text);
    if (title.isEmpty || minutes == null || minutes < 1) {
      setState(
        () => _error = title.isEmpty
            ? 'Enter a reminder message.'
            : 'Enter an interval of at least 1 minute.',
      );
      return;
    }
    setState(() => _error = null);
    widget.onAdd(CustomReminder(title: title, minutes: minutes));
    _title.clear();
  }

  InputDecoration _decoration(String label, {String? hint, String? suffix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.border),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      floatingLabelStyle: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
      ),
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      suffixText: suffix,
      suffixStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      filled: true,
      fillColor: AppTheme.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      enabledBorder: border,
      border: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: AppTheme.accentColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 14,
      fontFamily: 'Inter',
      height: 1.4,
    );
    final message = TextField(
      controller: _title,
      style: style,
      cursorColor: AppTheme.accentColor,
      decoration: _decoration(
        'Reminder message',
        hint: 'e.g. Rest your shoulders',
      ),
      onSubmitted: (_) => _add(),
    );
    final interval = SizedBox(
      width: 124,
      child: TextField(
        controller: _minutes,
        style: style.copyWith(fontFeatures: [FontFeature.tabularFigures()]),
        cursorColor: AppTheme.accentColor,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _decoration('Repeat every', suffix: 'min'),
        onSubmitted: (_) => _add(),
      ),
    );
    final add = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        backgroundColor: AppTheme.surfaceElevated,
        side: BorderSide(color: AppTheme.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(CupertinoIcons.add, size: 16),
      label: const Text('Add reminder'),
      onPressed: _add,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    message,
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [interval, add],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: message),
                  const SizedBox(width: 12),
                  interval,
                  const SizedBox(width: 12),
                  add,
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
