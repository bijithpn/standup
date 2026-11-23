import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
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
        Text(
          'App themes and styling',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Text(
          'Personalize the look and feel of BreakMate across the dashboard, menu bar, and break overlays.',
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        LayoutBuilder(
          builder: (context, box) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: box.maxWidth >= 480 ? 3 : 2,
              mainAxisSpacing: AppTheme.space12,
              crossAxisSpacing: AppTheme.space12,
              mainAxisExtent: 88,
            ),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final p = presets[index];
              return ThemePresetCard(
                preset: p,
                isSelected: p.id == currentPreset.id,
                onTap: () => _controller.setPreset(p.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
