import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/shared/widgets/app_dropdown.dart';
import 'package:standup/shared/widgets/minimal_controls.dart';

Widget sectionHeader(String title, {String? subtitle}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 0, top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
            fontFamily: 'Satoshi',
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ],
    ),
  );
}

Widget buildCard(List<Widget> children) {
  return Container(
    margin: const EdgeInsets.only(bottom: 24),
    decoration: AppTheme.cleanCardDecoration.copyWith(
      color: AppTheme.cardBackground.withValues(alpha: 0.4),
      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

Widget divider() {
  return Divider(
    height: 1,
    thickness: 0.5,
    color: AppTheme.separatorColor,
    indent: 16,
    endIndent: 16,
  );
}

Widget toggleRow(
  String label,
  String subtitle,
  bool value,
  ValueChanged<bool> onChanged,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0,
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.8,
          alignment: Alignment.centerRight,
          child: CupertinoSwitch(
            value: value,
            activeTrackColor: AppTheme.accentColor,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

Widget inputRow(String label, String value, {VoidCallback? onTap}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontFamily: 'Satoshi',
            ),
          ),
        ),
        MinimalButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          onPressed: onTap,
          isSecondary: true,
          borderRadius: BorderRadius.circular(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 12,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget sliderRow(
  String label,
  double value,
  ValueChanged<double> onChanged, {
  double min = 0.0,
  double max = 1.0,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isSmallScreen = constraints.maxWidth < 500;
      final padding = isSmallScreen ? 16.0 : 20.0;

      return Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: isSmallScreen ? 13 : 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                SizedBox(
                  width: isSmallScreen ? 120 : 180,
                  child: Transform.scale(
                    scale: 0.85,
                    alignment: Alignment.centerRight,
                    child: MinimalSlider(
                      value: value.clamp(min, max),
                      min: min,
                      max: max,
                      onChanged: onChanged,
                      activeColor: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget dropdownRow(
  String label,
  String value,
  List<String> options,
  ValueChanged<String?> onChanged,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isSmallScreen = constraints.maxWidth < 500;
      final padding = isSmallScreen ? 16.0 : 20.0;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: isSmallScreen ? 13 : 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            AppDropdown<String>(
              value: options.contains(value)
                  ? value
                  : (options.isNotEmpty ? options.first : ''),
              onChanged: onChanged,
              items: options
                  .map(
                    (option) => AppDropdownItem<String>(
                      value: option,
                      label: option.toUpperCase(),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
    },
  );
}

Widget textFieldRow(
  String label,
  String value,
  ValueChanged<String> onChanged,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: CupertinoTextField(
            placeholder: value,
            placeholderStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onSubmitted: onChanged,
          ),
        ),
      ],
    ),
  );
}

Widget buildListRow(
  String label,
  String subtitle,
  bool? value,
  IconData icon,
  ValueChanged<bool>? onChanged, {
  VoidCallback? onTap,
  Widget? trailing,
}) {
  final content = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.accentColor, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (value != null)
          Transform.scale(
            scale: 0.8,
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppTheme.accentColor,
            ),
          ),
        // ignore: use_null_aware_elements
        if (trailing != null) trailing,
      ],
    ),
  );

  if (onTap != null) {
    return MinimalButton(
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: content,
    );
  }

  return content;
}

Widget inlineDropdown(
  String value,
  List<String> options,
  ValueChanged<String?> onChanged,
) {
  return AppDropdown<String>(
    value: options.contains(value)
        ? value
        : (options.isNotEmpty ? options.first : ''),
    onChanged: onChanged,
    items: options
        .map(
          (option) => AppDropdownItem<String>(
            value: option,
            label: option.toUpperCase(),
          ),
        )
        .toList(),
  );
}

void showPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String suffix,
  required ValueChanged<String> onSelected,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      return InkWell(
                        onTap: () {
                          onSelected(opt);
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Center(
                            child: Text(
                              '$opt$suffix',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: MinimalButton(
                    isSecondary: true,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: child,
        ),
      );
    },
  );
}

List<String> timeOptions() {
  return [
    for (var hour = 0; hour < 24; hour++)
      for (final minute in const [0, 30])
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
  ];
}
