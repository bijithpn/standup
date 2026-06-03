import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GoalsSection extends StatelessWidget {
  const GoalsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsRepository>(
      builder: (context, repo, child) {
        final s = repo.currentSettings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              'Personal Goals',
              subtitle: 'Set daily and weekly targets for your wellbeing.',
            ),
            const SizedBox(height: 16),

            buildCard([
              sliderRow(
                'Daily Focus Goal (${s.dailyWorkGoalHours}h)',
                s.dailyWorkGoalHours.toDouble(),
                (val) {
                  repo.save(s.copyWith(dailyWorkGoalHours: val.round()));
                },
                min: 1,
                max: 12,
              ),
              divider(),
              sliderRow(
                'Daily Break Goal (${s.dailyBreakGoalCount})',
                s.dailyBreakGoalCount.toDouble(),
                (val) {
                  repo.save(s.copyWith(dailyBreakGoalCount: val.round()));
                },
                min: 1,
                max: 30,
              ),
              divider(),
              sliderRow(
                'Sitting Limit (${s.maxContinuousSittingMinutes}m)',
                s.maxContinuousSittingMinutes.toDouble(),
                (val) {
                  repo.save(
                    s.copyWith(maxContinuousSittingMinutes: val.round()),
                  );
                },
                min: 20,
                max: 120,
              ),
              divider(),
              sliderRow(
                'Weekly Consistency (${s.weeklyConsistencyTargetDays} days)',
                s.weeklyConsistencyTargetDays.toDouble(),
                (val) {
                  repo.save(
                    s.copyWith(weeklyConsistencyTargetDays: val.round()),
                  );
                },
                min: 1,
                max: 7,
              ),
            ]),

            const SizedBox(height: 24),
            sectionHeader(
              'Calendar Integration',
              subtitle: 'Automatically pause breaks during your meetings.',
            ),
            const SizedBox(height: 16),
            buildCard([
              toggleRow(
                'Enable Calendar Sync',
                'Check for upcoming meetings to avoid interruptions.',
                s.calendarEnabled,
                (val) {
                  repo.save(s.copyWith(calendarEnabled: val));
                },
              ),
            ]),
          ],
        );
      },
    );
  }
}
