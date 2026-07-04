import 'package:flutter/material.dart';
import 'package:breakmate/shared/shared.dart';

class CustomSegmentedControl extends StatelessWidget {
  final Map<String, String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const CustomSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.entries.map((entry) {
            final isSelected = entry.key == selectedValue;
            return GestureDetector(
              onTap: () => onSelected(entry.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : Colors.transparent,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
