import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Keeps less frequent controls reachable through a keyboard-focusable disclosure.
class AdvancedSettings extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const AdvancedSettings({
    super.key,
    this.title = 'Advanced settings',
    this.subtitle,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      expansionAnimationStyle:
          MediaQuery.maybeDisableAnimationsOf(context) == true
          ? AnimationStyle.noAnimation
          : null,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: AppTheme.textSecondary,
      collapsedIconColor: AppTheme.textSecondary,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children.skipWhile((child) => child is Divider).toList(),
        ),
      ],
    ),
  );
}
