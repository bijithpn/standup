import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  SettingsModel get _settings => settings;
  void _save(SettingsModel s) => onSave(s);

  @override
  Widget build(BuildContext context) {
    return _buildIntelligentDetection();
  }

  Widget _buildIntelligentDetection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Smart Detection'),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Text(
            'Automatically pauses your breaks when you are busy.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        buildCard([
          toggleRow(
            'Video Calls Detection',
            'Pause breaks during Zoom, Meet, Teams, etc.',
            _settings.detectVideoCalls,
            (v) => _save(_settings.copyWith(detectVideoCalls: v)),
          ),
          divider(),
          toggleRow(
            'Meeting Detection',
            'Sync with calendar to pause during meetings',
            _settings.detectMeetings,
            (v) => _save(
              _settings.copyWith(detectMeetings: v, calendarEnabled: v),
            ),
          ),
          divider(),
          toggleRow(
            'Focus Mode Detection',
            'Respect macOS Do Not Disturb & Focus Modes',
            _settings.respectFocusMode,
            (v) => _save(_settings.copyWith(respectFocusMode: v)),
          ),
        ]),
      ],
    );
  }
}
