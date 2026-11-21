import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:breakmate/shared/theme/app_theme.dart';

class ActivityTrackingIntro extends StatelessWidget {
  const ActivityTrackingIntro({super.key});

  static Future<bool> show(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => const ActivityTrackingIntro(),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: AppTheme.border),
      ),

      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Understand where your time goes',
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'BreakMate can record which application is in front of you and '
                'for how long, then turn that into a picture of your working '
                'day.',
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              _Group(
                title: 'What is recorded',
                icon: CupertinoIcons.checkmark,
                items: const <String>[
                  'The application name',
                  'When it was in front, and for how long',
                  'Idle periods and your breaks',
                ],
              ),
              const SizedBox(height: 16),
              _Group(
                title: 'What is never read',
                icon: CupertinoIcons.nosign,
                items: const <String>[
                  'Window titles, documents or messages',
                  'What you type, copy or browse',
                  'Screenshots of any kind',
                ],
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      CupertinoIcons.lock,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This stays on your computer. Nothing is uploaded, and '
                        'you can turn it off or delete the history at any time '
                        'in Privacy.',
                        style: TextStyle(
                          fontFeatures: AppTheme.tabular,
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.55,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      textStyle: const TextStyle(
                        fontFeatures: AppTheme.tabular,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Not now'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.gray950,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontFeatures: AppTheme.tabular,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Start tracking'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items, required this.icon});

  final String title;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontFeatures: AppTheme.tabular,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ClearActivityHistoryDialog extends StatelessWidget {
  const ClearActivityHistoryDialog({super.key, required this.segmentCount});

  final int segmentCount;

  static Future<bool> show(
    BuildContext context, {
    required int segmentCount,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ClearActivityHistoryDialog(segmentCount: segmentCount),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: AppTheme.border),
      ),
      title: Text(
        'Clear activity history?',
        style: TextStyle(
          fontFeatures: AppTheme.tabular,
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Text(
          segmentCount == 0
              ? 'There is no recorded activity to delete.'
              : 'This permanently deletes $segmentCount recorded '
                    '${segmentCount == 1 ? 'entry' : 'entries'} — your timeline, '
                    'application totals and every insight drawn from them. '
                    'Your settings and break history are not affected.\n\n'
                    'This cannot be undone.',
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.6,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: segmentCount == 0
              ? null
              : () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: AppTheme.onColor(AppTheme.error),
          ),
          child: const Text('Delete history'),
        ),
      ],
    );
  }
}
