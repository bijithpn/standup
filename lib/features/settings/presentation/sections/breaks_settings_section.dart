import 'package:breakmate/features/settings/presentation/sections/breaks/break_appearance_settings.dart';
import 'package:breakmate/features/settings/presentation/sections/breaks/break_intensity_settings.dart';
import 'package:breakmate/features/settings/presentation/sections/breaks/break_profile_selector.dart';
import 'package:breakmate/features/settings/presentation/sections/breaks/custom_intervals_editor.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';

class BreaksSettingsSection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const BreaksSettingsSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<BreaksSettingsSection> createState() => _BreaksSettingsSectionState();
}

class _BreaksSettingsSectionState extends State<BreaksSettingsSection> {
  int _breaksSubTab = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              'Break Configuration',
              subtitle:
                  'Pick a rhythm, fine-tune the timings, choose what a break shows, and style it.',
            ),
            const SizedBox(height: 12),

            segmentedControl(
              ['Profiles', 'Intervals', 'Options', 'Themes'],
              _breaksSubTab,
              (i) => setState(() => _breaksSubTab = i),
              isSmall: isSmallScreen,
            ),

            SizedBox(height: isSmallScreen ? 24 : 32),

            if (_breaksSubTab == 0)
              BreakProfileSelector(
                settings: widget.settings,
                onSave: widget.onSave,
              ),
            if (_breaksSubTab == 1)
              CustomIntervalsEditor(
                settings: widget.settings,
                onSave: widget.onSave,
              ),
            if (_breaksSubTab == 2)
              BreakIntensitySettings(
                settings: widget.settings,
                onSave: widget.onSave,
              ),
            if (_breaksSubTab == 3)
              BreakAppearanceSettings(
                settings: widget.settings,
                onSave: widget.onSave,
              ),
          ],
        );
      },
    );
  }
}
