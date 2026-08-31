import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import '../application/theme_controller.dart';
import 'widgets/theme_preset_card.dart';

class ThemeSettingsSection extends StatefulWidget {
  const ThemeSettingsSection({super.key});

  @override
  State<ThemeSettingsSection> createState() => _ThemeSettingsSectionState();
}

class _ThemeSettingsSectionState extends State<ThemeSettingsSection> {
  late final ThemeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = sl<ThemeController>();
    _controller.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentPreset = _controller.currentPreset;
    final presets = _controller.availablePresets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('App Themes & Styling'),
        const SizedBox(height: 8),
        Text(
          'Personalize the look and feel of BreakMate across the dashboard, menu bar, and break overlays.',
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 130,
          ),
          itemCount: presets.length,
          itemBuilder: (context, index) {
            final p = presets[index];
            final isSelected = p.id == currentPreset.id;
            return ThemePresetCard(
              preset: p,
              isSelected: isSelected,
              onTap: () async {
                await _controller.setPreset(p.id);
                if (context.mounted) {
                  Toast.showSuccess(context, 'Theme changed to ${p.name}');
                }
              },
            );
          },
        ),
      ],
    );
  }
}
