import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class AppDropdown<T> extends StatelessWidget {
  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final double? width;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final selectedItem = items.firstWhere(
      (item) => item.value == value,
      orElse: () => items.first,
    );

    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(hoverColor: Colors.white.withValues(alpha: 0.05)),
        child: PopupMenuButton<T>(
          initialValue: value,
          tooltip: label ?? 'Select option',
          onSelected: onChanged,
          offset: const Offset(0, 4),
          position: PopupMenuPosition.under,
          constraints: const BoxConstraints(maxHeight: 250),
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 0.8),
          ),
          color: const Color(0xFF161616),
          itemBuilder: (context) => items.map((item) {
            final isSelected = item.value == value;
            return PopupMenuItem<T>(
              value: item.value,
              height: 34,
              child: Row(
                children: [
                  if (item.customChild != null)
                    Expanded(child: item.customChild!)
                  else ...[
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 15,
                        color: isSelected
                            ? AppTheme.accentColor
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.accentColor
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  if (isSelected)
                    Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 13,
                      color: AppTheme.accentColor,
                    ),
                ],
              ),
            );
          }).toList(),
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedItem.icon != null) ...[
                        Icon(
                          selectedItem.icon,
                          size: 16,
                          color: AppTheme.accentColor,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(child: itemHeaderWidget(selectedItem)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget itemHeaderWidget(AppDropdownItem<T> item) {
    if (item.customChild != null) {
      return item.customChild!;
    }
    return Text(
      item.label,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class AppDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Widget? customChild;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.customChild,
  });
}
