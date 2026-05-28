import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class ClockOutSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const ClockOutSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  SettingsModel get _settings => settings;
  void _save(SettingsModel s) => onSave(s);

  @override
  Widget build(BuildContext context) {
    return _buildClockOut();
  }

  Widget _buildClockOut() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Balance'),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Text(
            'Establish healthy boundaries with fixed rest hours.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        buildCard([
          toggleRow(
            'Workday Enforcement',
            'Remind me to clock out at end of day',
            _settings.enableClockOut,
            (v) => _save(_settings.copyWith(enableClockOut: v)),
          ),
          if (_settings.enableClockOut) ...[
            divider(),
            inputRow(
              'End Workday At',
              '',
              trailing: inlineDropdown(
                _settings.clockOutTime,
                ['16:00', '16:30', '17:00', '17:30', '18:00', '18:30', '19:00'],
                (v) {
                  if (v != null) {
                    _save(_settings.copyWith(clockOutTime: v));
                  }
                },
              ),
            ),
          ],
        ]),
      ],
    );
  }
}
