import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/app_theme_preset.dart';

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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? p.accent
                  : _isHovered
                  ? p.accent.withValues(alpha: 0.5)
                  : p.border,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : _isHovered
                ? [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Swatch preview header
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
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 13,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
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
              const SizedBox(height: 10),
              // Palette preview strip
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
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
              const SizedBox(height: 10),
              // Description
              Text(
                p.description,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 11,
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
