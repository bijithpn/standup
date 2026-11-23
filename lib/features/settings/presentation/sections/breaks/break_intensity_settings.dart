import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/display/controllers/display_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Settings > Break display options: which monitors dim, wellness notes and break music.
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
        sectionHeader('Display options'),
        buildCard([
          toggleRow('Show on all displays', '', settings.showOnAllDisplays, (
            val,
          ) {
            onSave(settings.copyWith(showOnAllDisplays: val));
          }),
          divider(),
          toggleRow(
            'Show wellness notes',
            'Tips and exercise notes on break templates',
            settings.showExercisesInBreak,
            (val) {
              onSave(settings.copyWith(showExercisesInBreak: val));
            },
          ),
          divider(),
          toggleRow(
            'Play lo-fi music during breaks',
            '',
            settings.playMusicDuringBreak,
            (val) {
              onSave(settings.copyWith(playMusicDuringBreak: val));
            },
          ),
        ]),
        sectionHeader('Connected displays'),
        ListenableBuilder(
          listenable: sl<DisplayController>(),
          builder: (context, _) {
            final displays = sl<DisplayController>().displays;
            if (displays.isEmpty) {
              return buildCard([
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No external displays detected.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ]);
            }
            return buildCard(
              displays.map((display) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${display.width.toInt()}x${display.height.toInt()}${display.isPrimary ? ' · Primary' : ''}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),

                      Text(
                        'Active',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
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
