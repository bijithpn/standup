import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class FocusDetectionSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const FocusDetectionSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Smart Detection'),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Text(
            'Adapts your breaks when you are busy, without interrupting your focus timer.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),

        buildCard([
          toggleRow(
            'Video Calls Detection',
            'Show a quiet reminder instead of the full break during Zoom, Meet, Teams, etc.',
            settings.detectVideoCalls,
            (v) => onSave(settings.copyWith(detectVideoCalls: v)),
          ),
          divider(),
          // Meeting detection from the calendar is configured in one place.
          actionRow(
            label: 'Meetings from your calendar',
            subtitle: settings.detectMeetings && settings.calendarEnabled
                ? 'On — breaks stay quiet during calendar events.'
                : 'Off — set up in Calendar Sync.',
            buttonText: 'Open Calendar Sync',
            onPressed: () =>
                sl<AppNavigationService>().openSection('Calendar Sync'),
          ),
          divider(),
          toggleRow(
            'Presentation Pause',
            'Pause breaks while a fullscreen slideshow or presentation is showing',
            settings.presentationPauseEnabled,
            (v) => onSave(settings.copyWith(presentationPauseEnabled: v)),
          ),
        ]),
      ],
    );
  }
}
