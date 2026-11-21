import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/app_theme_preset.dart';

/// Selectable swatch card that previews a preset in its own colors.
class ThemePresetCard extends StatefulWidget {
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
  State<ThemePresetCard> createState() => _ThemePresetCardState();
}

class _ThemePresetCardState extends State<ThemePresetCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.preset;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: TapTarget(
        onTap: widget.onTap,
        selected: widget.isSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: widget.isSelected
                  ? p.accent
                  : _isHovered
                  ? Color.lerp(p.border, p.textPrimary, 0.25)!
                  : p.border,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: p.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.border, width: 1),
                    ),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isSelected)
                    Icon(LucideIcons.circleCheck, size: 16, color: p.accent),
                ],
              ),
              const SizedBox(height: AppTheme.space8),

              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(child: Container(color: p.surface)),
                      Expanded(child: Container(color: p.surfaceElevated)),
                      Expanded(child: Container(color: p.accent)),
                      Expanded(child: Container(color: p.shortBreak)),
                      Expanded(child: Container(color: p.longBreak)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space8),

              Text(
                p.description,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                  fontFamily: 'Inter',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
