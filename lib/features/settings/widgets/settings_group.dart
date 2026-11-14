import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// A visual group of related controls with one consistent divider per row.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  const SettingsGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 24),
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: children[index],
          ),
        ],
      ],
    ),
  );
}

/// Gives pickers and chip controls the same label spacing as setting rows.
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
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class SettingsNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const SettingsNote(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
