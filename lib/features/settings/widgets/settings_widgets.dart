import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'settings_group.dart';

// Shared row/section builders used by every settings page so they look consistent.
const _rowPadding = EdgeInsets.symmetric(vertical: AppTheme.space12);

Widget sectionHeader(String title, {String? subtitle}) {
  return Padding(
    padding: const EdgeInsets.only(
      left: AppTheme.space4,
      bottom: AppTheme.space8,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ],
    ),
  );
}

Widget buildCard(List<Widget> children) => SettingsGroup(children: children);

Widget divider() {
  return Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle);
}

Widget _rowLabel(String label, String? helper, {Color? color}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: color ?? AppTheme.textPrimary,
        ),
      ),
      if (helper != null && helper.isNotEmpty) ...[
        const SizedBox(height: AppTheme.space4),
        Text(
          helper,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    ],
  );
}

Widget _row(Widget label, Widget control) {
  return Padding(
    padding: _rowPadding,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: AppTheme.space16),
          control,
        ],
      ),
    ),
  );
}

Widget _switch(bool value, ValueChanged<bool>? onChanged) {
  return CupertinoSwitch(
    value: value,
    activeTrackColor: AppTheme.accentColor,
    inactiveTrackColor: AppTheme.border,
    thumbColor: value ? AppTheme.onAccent : AppTheme.textPrimary,
    onChanged: onChanged,
  );
}

Widget toggleRow(
  String label,
  String subtitle,
  bool value,
  ValueChanged<bool> onChanged,
) {
  return MergeSemantics(
    child: _row(_rowLabel(label, subtitle), _switch(value, onChanged)),
  );
}

Widget valueRow(String label, String value) {
  return _row(
    _rowLabel(label, null),
    Text(
      value,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontFeatures: AppTheme.tabular,
      ),
    ),
  );
}

Widget inputRow(
  String label,
  String value, {
  VoidCallback? onTap,
  Widget? trailing,
}) {
  return _row(
    _rowLabel(label, null),
    trailing ??
        MinimalButton(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space8,
          ),
          onPressed: onTap,
          isSecondary: true,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 88),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 12,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
  );
}

Widget sliderRow(
  String label,
  double value,
  ValueChanged<double> onChanged, {
  ValueChanged<double>? onChangeEnd,
  double min = 0.0,
  double max = 1.0,
}) {
  return _row(
    _rowLabel(label, null),
    SizedBox(
      width: 176,
      child: MinimalSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
        activeColor: AppTheme.accentColor,
      ),
    ),
  );
}

Widget dropdownRow(
  String label,
  String value,
  List<String> options,
  ValueChanged<String?> onChanged,
) {
  return _row(
    _rowLabel(label, null),
    inlineDropdown(value, options, onChanged),
  );
}

Widget textFieldRow(
  String label,
  String value,
  ValueChanged<String> onChanged,
) {
  return _row(
    _rowLabel(label, null),
    SizedBox(
      width: 224,
      child: CupertinoTextField(
        placeholder: value,
        placeholderStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: BoxDecoration(
          color: AppTheme.contentBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space8,
        ),
        onSubmitted: onChanged,
      ),
    ),
  );
}

Widget buildListRow(
  String label,
  String subtitle,
  bool? value,
  ValueChanged<bool>? onChanged, {
  VoidCallback? onTap,
  Widget? trailing,
}) {
  final content = _row(
    _rowLabel(label, subtitle),
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null) _switch(value, onChanged),
        ?trailing,
        if (onTap != null)
          Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AppTheme.textMuted,
          ),
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
            label: _optionLabel(option),
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
  String? selected,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: AppTheme.scrim,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, anim1, anim2) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 440),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    Divider(height: 1, color: AppTheme.borderSubtle),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: AppTheme.space16,
                          endIndent: AppTheme.space16,
                          color: AppTheme.borderSubtle,
                        ),
                        itemBuilder: (context, index) {
                          final opt = options[index];
                          return InkWell(
                            hoverColor: AppTheme.hoverOverlay,
                            onTap: () {
                              onSelected(opt);
                              Navigator.pop(context);
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 40),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$opt$suffix',
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          fontFamily: 'Inter',
                                          fontFeatures: AppTheme.tabular,
                                        ),
                                      ),
                                    ),
                                    if (opt == selected)
                                      Icon(
                                        CupertinoIcons.checkmark_alt,
                                        size: 16,
                                        color: AppTheme.accent,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Divider(height: 1, color: AppTheme.borderSubtle),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.space12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: MinimalButton(
                          isSecondary: true,
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            begin: 0.97,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

Widget segmentedControl(
  List<String> options,
  int selected,
  ValueChanged<int> onSelected, {
  bool isSmall = false,
  bool expand = true,
}) {
  return Container(
    width: expand ? double.infinity : null,
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.asMap().entries.map((entry) {
          final isSelected = entry.key == selected;
          return Semantics(
            button: true,
            selected: isSelected,
            onTap: () => onSelected(entry.key),
            label: entry.value,
            excludeSemantics: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TapTarget(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(entry.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 24),
                  padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: isSelected
                            ? AppTheme.textPrimary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: isSmall ? 12 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

Widget actionRow({
  required String label,
  required String subtitle,
  required String buttonText,
  required VoidCallback? onPressed,
  Color? buttonColor,
  bool isDestructive = false,
}) {
  final color = isDestructive
      ? AppTheme.error
      : (buttonColor ?? AppTheme.textPrimary);

  return _row(
    _rowLabel(label, subtitle, color: isDestructive ? AppTheme.error : null),
    MinimalButton(
      onPressed: onPressed,
      isSecondary: true,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      child: Text(
        buttonText,
        style: TextStyle(
          color: onPressed == null ? color.withValues(alpha: 0.5) : color,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

List<String> timeOptions() {
  return [
    for (var hour = 0; hour < 24; hour++)
      for (final minute in const [0, 30])
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
  ];
}

String _optionLabel(String option) {
  final text = option.replaceAll('_', ' ');
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}
