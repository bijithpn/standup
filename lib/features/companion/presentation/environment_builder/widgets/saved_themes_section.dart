import 'package:flutter/material.dart';
import 'package:breakmate/shared/shared.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/presentation/environment_builder/environment_builder_controller.dart';

class SavedThemesSection extends StatelessWidget {
  final EnvironmentBuilderController ctrl;
  final VoidCallback? onLoaded;

  const SavedThemesSection({super.key, required this.ctrl, this.onLoaded});

  @override
  Widget build(BuildContext context) {
    if (ctrl.savedThemes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved Themes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 12),
        for (final theme in ctrl.savedThemes)
          SavedThemeTile(
            theme: theme,
            onLoad: () {
              ctrl.loadForEditing(theme);
              onLoaded?.call();
            },
            onDelete: () => ctrl.deleteSavedTheme(theme.id),
          ),
      ],
    );
  }
}

class SavedThemeTile extends StatelessWidget {
  final CustomEnvironmentTheme theme;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const SavedThemeTile({
    super.key,
    required this.theme,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Column(
                children: [
                  Expanded(child: Container(color: Color(theme.baseColorArgb))),
                  Expanded(
                    child: Container(color: Color(theme.groundTintArgb)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theme.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  theme.id,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 16),
            color: AppTheme.textSecondary,
            tooltip: 'Load for editing',
            onPressed: onLoad,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            color: AppTheme.error,
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: AppTheme.border),
        ),
        title: Text(
          'Delete Theme',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Delete "${theme.name}"? This cannot be undone.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
