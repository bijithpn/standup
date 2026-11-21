import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import '../../domain/app_theme_preset.dart';

/// Compact swatch tile that previews a preset in its own colors.
class ThemePresetCard extends StatelessWidget {
  final AppThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemePresetCard({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = preset;

    return Tooltip(
      message: p.description,
      waitDuration: const Duration(milliseconds: 400),
      child: TapTarget(
        onTap: onTap,
        selected: isSelected,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space12),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isSelected ? p.accent : p.border,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: AppTheme.space4),
                    Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 16,
                      color: p.accent,
                    ),
                  ],
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in [
                        p.surface,
                        p.surfaceCard,
                        p.accent,
                        p.textPrimary,
                        p.shortBreak,
                      ])
                        Expanded(child: ColoredBox(color: c)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
