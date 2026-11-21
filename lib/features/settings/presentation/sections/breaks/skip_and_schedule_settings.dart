import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/break_system/application/skip_policy.dart';
import 'package:breakmate/features/settings/break_profile.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Settings > Options: daily skip limit, skip reasons and per-period break profiles. Stored in prefs, not the settings model.
class SkipAndScheduleSettings extends StatefulWidget {
  const SkipAndScheduleSettings({super.key});

  @override
  State<SkipAndScheduleSettings> createState() =>
      _SkipAndScheduleSettingsState();
}

class _SkipAndScheduleSettingsState extends State<SkipAndScheduleSettings> {
  static const _limits = [0, 1, 2, 3, 5, 10];
  static const _defaultProfile = 'Base profile';

  String _limitLabel(int v) => v == 0 ? 'Unlimited' : '$v per day';

  String _profileName(String id) {
    for (final p in BreakProfile.presets) {
      if (p.id == id) return p.name;
    }
    return _defaultProfile;
  }

  String _profileIdFor(String name) {
    for (final p in BreakProfile.presets) {
      if (p.name == name) return p.id;
    }
    return '';
  }

  void _scheduleChanged() {
    setState(() {});
    sl<BreakController>().refreshScheduledProfile();
  }

  @override
  Widget build(BuildContext context) {
    final counts = SkipPolicy.reasonCounts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Skipping',
          subtitle: 'Limit how often breaks can be skipped.',
        ),
        buildCard([
          dropdownRow(
            'Daily skip limit',
            _limitLabel(SkipPolicy.dailyLimit),
            _limits.map(_limitLabel).toList(),
            (v) {
              if (v == null) return;
              SkipPolicy.dailyLimit = _limits.firstWhere(
                (l) => _limitLabel(l) == v,
              );
              setState(() {});
            },
          ),
          divider(),
          toggleRow(
            'Ask why when skipping',
            'Pick a quick reason when you skip a break.',
            SkipPolicy.reasonsEnabled,
            (v) => setState(() => SkipPolicy.reasonsEnabled = v),
          ),
          if (counts.isNotEmpty) ...[
            divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final e in counts.entries)
                    Text(
                      '${e.key} ${e.value}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        sectionHeader(
          'Time-of-day profiles',
          subtitle: 'Use a different break rhythm for each part of the day.',
        ),
        buildCard([
          toggleRow(
            'Switch profile by time of day',
            'Morning 5–12, afternoon 12–17, evening 17–5',
            TimeOfDayProfiles.enabled,
            (v) {
              TimeOfDayProfiles.enabled = v;
              _scheduleChanged();
            },
          ),
          if (TimeOfDayProfiles.enabled)
            for (final part in DayPart.values) ...[
              divider(),
              dropdownRow(
                part.name[0].toUpperCase() + part.name.substring(1),
                _profileName(TimeOfDayProfiles.profileId(part)),
                [_defaultProfile, ...BreakProfile.presets.map((p) => p.name)],
                (v) {
                  if (v == null) return;
                  TimeOfDayProfiles.setProfileId(part, _profileIdFor(v));
                  _scheduleChanged();
                },
              ),
            ],
        ]),
      ],
    );
  }
}
