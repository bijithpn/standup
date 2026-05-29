import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Color palette showcase for design reference
/// Run this in a test route to visualize all colors
class ColorPaletteShowcase extends StatelessWidget {
  const ColorPaletteShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BreakMate Color Palette',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Minimal Modern Design System',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 48),

            _buildSection('Primary Colors', [
              _ColorItem('Primary', AppTheme.primary, '#6366F1'),
              _ColorItem('Primary Light', AppTheme.primaryLight, '#818CF8'),
              _ColorItem('Primary Dark', AppTheme.primaryDark, '#4F46E5'),
            ]),

            _buildSection('Break Colors', [
              _ColorItem('Short Break', AppTheme.shortBreak, '#06B6D4'),
              _ColorItem('Long Break', AppTheme.longBreak, '#8B5CF6'),
            ]),

            _buildSection('Surfaces', [
              _ColorItem('Surface', AppTheme.surface, '#18181B'),
              _ColorItem('Surface Card', AppTheme.surfaceCard, '#1F1F23'),
              _ColorItem(
                'Surface Elevated',
                AppTheme.surfaceElevated,
                '#27272A',
              ),
            ]),

            _buildSection('Borders', [
              _ColorItem('Border', AppTheme.border, '#3F3F46'),
              _ColorItem('Border Subtle', AppTheme.borderSubtle, '#27272A'),
            ]),

            _buildSection('Text', [
              _ColorItem('Text Primary', AppTheme.textPrimary, '#FAFAFA'),
              _ColorItem('Text Secondary', AppTheme.textSecondary, '#A1A1AA'),
              _ColorItem('Text Muted', AppTheme.textMuted, '#71717A'),
            ]),

            _buildSection('Semantic', [
              _ColorItem('Success', AppTheme.success, '#10B981'),
              _ColorItem('Warning', AppTheme.warning, '#F59E0B'),
              _ColorItem('Error', AppTheme.error, '#EF4444'),
              _ColorItem('Info', AppTheme.info, '#3B82F6'),
            ]),

            _buildSection('Grays', [
              _ColorItem('Gray 50', AppTheme.gray50, '#FAFAFA'),
              _ColorItem('Gray 100', AppTheme.gray100, '#F5F5F5'),
              _ColorItem('Gray 200', AppTheme.gray200, '#E5E5E5'),
              _ColorItem('Gray 300', AppTheme.gray300, '#D4D4D4'),
              _ColorItem('Gray 400', AppTheme.gray400, '#A3A3A3'),
              _ColorItem('Gray 500', AppTheme.gray500, '#737373'),
              _ColorItem('Gray 600', AppTheme.gray600, '#525252'),
              _ColorItem('Gray 700', AppTheme.gray700, '#404040'),
              _ColorItem('Gray 800', AppTheme.gray800, '#262626'),
              _ColorItem('Gray 900', AppTheme.gray900, '#171717'),
              _ColorItem('Gray 950', AppTheme.gray950, '#0A0A0A'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<_ColorItem> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: colors.map((item) => _buildColorCard(item)).toList(),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildColorCard(_ColorItem item) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMd),
                topRight: Radius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.hex,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorItem {
  final String name;
  final Color color;
  final String hex;

  _ColorItem(this.name, this.color, this.hex);
}
