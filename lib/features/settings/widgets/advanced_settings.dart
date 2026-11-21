import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'settings_group.dart';

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
    margin: const EdgeInsets.only(bottom: AppTheme.space24),
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      border: Border.all(color: AppTheme.borderSubtle),
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
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: AppTheme.space4),
              child: Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space4,
      ),
      childrenPadding: EdgeInsets.zero,
      children: [
        Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
        SettingsRows(children: children),
      ],
    ),
  );
}
