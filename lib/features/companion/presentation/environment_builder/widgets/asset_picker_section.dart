import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'asset_picker_tile.dart';

// A labelled horizontal scroll row of [AssetPickerTile]s for a single
// asset category (sky, ground, rocks, etc.).
class AssetPickerSection extends StatelessWidget {
  final String label;
  final String? subtitle;
  final List<String> paths;
  final String selectedPath;
  final ValueChanged<String> onSelected;

  const AssetPickerSection({
    super.key,
    required this.label,
    this.subtitle,
    required this.paths,
    required this.selectedPath,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: label, subtitle: subtitle),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 1),
              itemCount: paths.length,
              itemBuilder: (context, index) {
                final path = paths[index];
                return AssetPickerTile(
                  assetPath: path,
                  isSelected: path == selectedPath,
                  onTap: () {
                    if (path == selectedPath) {
                      onSelected('none');
                    } else {
                      onSelected(path);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? subtitle;

  const _SectionLabel({required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            '· $subtitle',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ],
    );
  }
}
