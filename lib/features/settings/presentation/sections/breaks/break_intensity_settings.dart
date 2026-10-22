import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/display/controllers/display_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class BreakIntensitySettings extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const BreakIntensitySettings({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Display Options'),
        buildCard([
          toggleRow(
            'Show on All Displays',
            'Dim all monitors when taking a break.',
            settings.showOnAllDisplays,
            (val) {
              onSave(settings.copyWith(showOnAllDisplays: val));
            },
          ),
          divider(),
          toggleRow(
            'Show Wellness Notes',
            'Display tips and exercise notes on break templates.',
            settings.showExercisesInBreak,
            (val) {
              onSave(settings.copyWith(showExercisesInBreak: val));
            },
          ),
          divider(),
          toggleRow(
            'Play LoFi Music During Break',
            'Play relaxing LoFi music when on break.',
            settings.playMusicDuringBreak,
            (val) {
              onSave(settings.copyWith(playMusicDuringBreak: val));
            },
          ),
        ]),
        const SizedBox(height: 16),
        sectionHeader('Connected Displays'),
        ListenableBuilder(
          listenable: sl<DisplayController>(),
          builder: (context, _) {
            final displays = sl<DisplayController>().displays;
            if (displays.isEmpty) {
              return buildCard([
                Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No external displays detected or plugin not fully initialized.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ]);
            }
            return buildCard(
              displays.map((display) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              display.id,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Resolution: ${display.width.toInt()}x${display.height.toInt()} • Primary: ${display.isPrimary}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      // A status label, not a control: it used to be a button
                      // with an empty callback.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
