import 'package:flutter/material.dart';

import 'package:breakmate/shared/theme/app_theme.dart';

/// What BreakMate asks before it starts recording.
///
/// Shown once, before tracking is switched on for the first time. Consent for
/// something that runs quietly all day is worth asking for properly: the
/// dialog says what is recorded, what is deliberately not, and that the answer
/// can be changed later — and it can be declined without breaking anything.
class ActivityTrackingIntro extends StatelessWidget {
  const ActivityTrackingIntro({super.key});

  /// Returns true when the user agreed to switch tracking on.
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
      // The explainer is deliberately thorough, which makes it tall. On a
      // short window the content scrolls rather than overflowing, so the
      // decision buttons are always reachable.
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
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'BreakMate can record which application is in front of you and '
                'for how long, then turn that into a picture of your working '
                'day.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              _Group(
                title: 'What is recorded',
                tone: AppTheme.accent,
                icon: Icons.check_rounded,
                items: const <String>[
                  'The application name',
                  'When it was in front, and for how long',
                  'Idle periods and your breaks',
                ],
              ),
              const SizedBox(height: 14),
              _Group(
                title: 'What is never read',
                tone: AppTheme.success,
                icon: Icons.block_rounded,
                items: const <String>[
                  'Window titles, documents or messages',
                  'What you type, copy or browse',
                  'Screenshots of any kind',
                ],
              ),

              const SizedBox(height: 18),
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
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This stays on your computer. Nothing is uploaded, and '
                        'you can turn it off or delete the history at any time '
                        'in Privacy.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
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
                        fontFamily: 'Inter',
                        fontSize: 12.5,
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
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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
  const _Group({
    required this.title,
    required this.items,
    required this.icon,
    required this.tone,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 7),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 13, color: tone),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
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

/// Confirms deleting the recorded history.
///
/// Names the number of records at risk, because "clear history" means nothing
/// until you know whether it is an afternoon or three months.
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
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
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
            fontFamily: 'Inter',
            fontSize: 12.5,
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
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete history'),
        ),
      ],
    );
  }
}
