import 'settings_group.dart';
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
        sectionHeader('Reminder intensity'),
        NotificationIntensityPicker(settings: settings, onChanged: onSave),
        sectionHeader('Alerts'),
        SettingsGroup(
          children: [_buildSoundEnabled(), _buildNotificationsEnabled()],
        ),
        sectionHeader('Health reminders'),
        SettingsGroup(
          margin: const EdgeInsets.only(bottom: AppTheme.space8),
          children: [
            toggleRow(
              'Health reminders',
              'Nudges for eyes, posture, water and standing up',
              settings.healthRemindersEnabled,
              (v) => onSave(settings.copyWith(healthRemindersEnabled: v)),
            ),
            if (settings.healthRemindersEnabled) ...[
              _buildReminderPreviewRow(onPreview: _previewRandom),
              toggleRow(
                'Blink and screen-distance reminders',
                'A more frequent nudge to blink and sit back',
                settings.blinkRemindersEnabled,
                (v) => onSave(settings.copyWith(blinkRemindersEnabled: v)),
              ),
              if (Platform.isMacOS)
                toggleRow(
                  'Dismiss on mouse movement',
                  'Moving the mouse closes a new reminder after a short pause',
                  settings.dismissReminderOnMouseMove,
                  (v) =>
                      onSave(settings.copyWith(dismissReminderOnMouseMove: v)),
                ),
              if (kDebugMode && Platform.isMacOS) ...[
                _buildReminderPreviewRow(
                  label: 'Preview posture reminder (debug)',
                  onPreview: () => _showPreview('posture'),
                ),
                _buildReminderPreviewRow(
                  label: 'Preview water reminder (debug)',
                  onPreview: () => _showPreview('hydration'),
                ),
                _buildReminderPreviewRow(
                  label: 'Preview notification toast (debug)',
                  onPreview: () => NativeEnhancementsService.instance.showToast(
                    title: 'Time for a break',
                    body: 'Eye Rest',
                    sound: settings.soundEnabled,
                  ),
                ),
              ],
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            right: 4,
            bottom: AppTheme.space24,
          ),
          child: Text(
            'One reminder at a time, more often on busy days, at most 4 an '
            'hour. They hold back during meetings and around breaks.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
        sectionHeader('Focus and evening'),
        SettingsGroup(
          children: [
            if (settings.avoidBreakHour >= 0)
              toggleRow(
                'Avoid breaks around ${formatHourLabel(settings.avoidBreakHour)}',
                'Breaks due in that hour wait until the next one',
                true,
                (_) => onSave(settings.copyWith(avoidBreakHour: -1)),
              ),
            toggleRow(
              'Do Not Disturb in focus sessions',
              'macOS only. Needs Shortcuts named "BreakMate Focus On" and "BreakMate Focus Off"',
              settings.focusDndEnabled,
              (v) => onSave(settings.copyWith(focusDndEnabled: v)),
            ),
            toggleRow(
              'Evening eye care',
              'At 8 pm, turns on Night Shift (macOS) and suggests lower brightness',
              settings.eveningEyeCare,
              (v) => onSave(settings.copyWith(eveningEyeCare: v)),
            ),
          ],
        ),
        sectionHeader('Custom reminders'),
        SettingsGroup(
          children: [
            for (final r in settings.customReminders)
              buildListRow(
                r.title,
                'Every ${r.minutes} min',
                null,
                null,
                trailing: Tooltip(
                  message: 'Remove',
                  child: MinimalButton(
                    isGhost: true,
                    padding: const EdgeInsets.all(8),
                    child: Icon(
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
              ),
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
    );
  }

  Widget _buildSoundEnabled() {
    return toggleRow(
      'Sound',
      'A distinct tone for breaks and each reminder',
      settings.soundEnabled,
      (v) {
        onSave(settings.copyWith(soundEnabled: v));
        sl<TrayManagerService>().triggerActionAnimation();
      },
    );
  }

  Widget _buildNotificationsEnabled() {
    return toggleRow(
      'System notifications',
      'Show a notification when a break is due',
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
  }) => actionRow(
    label: label,
    subtitle: '',
    buttonText: 'Preview',
    onPressed: onPreview,
  );
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
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border,
      border: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: AppTheme.accentColor),
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
    final add = MinimalButton(
      isSecondary: true,
      onPressed: _add,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.add, size: 16),
          SizedBox(width: 8),
          Text('Add reminder'),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
            const SizedBox(height: 8),
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
