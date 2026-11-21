import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Rows separated by 1px hairlines inset 16px; explicit [Divider] children are dropped.
class SettingsRows extends StatelessWidget {
  final List<Widget> children;
  const SettingsRows({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = children.where((c) => c is! Divider).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: AppTheme.space16,
              endIndent: AppTheme.space16,
              color: AppTheme.borderSubtle,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            child: rows[index],
          ),
        ],
      ],
    );
  }
}

/// One rounded surface holding related rows.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  const SettingsGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: AppTheme.space24),
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      border: Border.all(color: AppTheme.borderSubtle),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    ),
    clipBehavior: Clip.antiAlias,
    child: SettingsRows(children: children),
  );
}

/// Label and optional helper for a control that does not fit on one line (chips, pickers).
class SettingsField extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  const SettingsField({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: AppTheme.space4),
          Text(
            description!,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
        const SizedBox(height: AppTheme.space8),
        child,
      ],
    ),
  );
}

class SettingsNote extends StatelessWidget {
  final String text;
  const SettingsNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: AppTheme.textSecondary,
      ),
    ),
  );
}
