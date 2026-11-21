import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

enum PillTone { active, ok, warn, off }

class StatusPill extends StatelessWidget {
  final String label;
  final PillTone tone;
  const StatusPill(this.label, {super.key, required this.tone});

  static Color colorFor(PillTone tone) => switch (tone) {
    PillTone.active => AppTheme.accentColor,
    PillTone.ok => AppTheme.success,
    PillTone.warn => AppTheme.warning,
    PillTone.off => AppTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs + 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
