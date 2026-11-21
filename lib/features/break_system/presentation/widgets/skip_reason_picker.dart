import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/application/skip_policy.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Asks why a break is being skipped; picking a reason skips, closing goes back to the break.
class SkipReasonPicker extends StatelessWidget {
  final ValueChanged<String> onReason;
  final VoidCallback onCancel;

  const SkipReasonPicker({
    super.key,
    required this.onReason,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why skip this break?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in SkipPolicy.reasons)
                      ActionChip(label: Text(r), onPressed: () => onReason(r)),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancel,
                    child: const Text('Back to break'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
