import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/constants/app_strings.dart';

class WellnessScoreCard extends StatelessWidget {
  final int productivityScore;
  final int wellnessScore;

  const WellnessScoreCard({
    super.key,
    required this.productivityScore,
    required this.wellnessScore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _scoreItem(
            'Productivity',
            productivityScore,
            AppTheme.accentColor,
            CupertinoIcons.bolt_fill,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _scoreItem(
            'Wellness',
            wellnessScore,
            const Color(0xFF10B981),
            CupertinoIcons.heart_fill,
          ),
        ),
      ],
    );
  }

  Widget _scoreItem(String label, int score, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.2,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Inter',
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/ 100',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getScoreInsight(label, score),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _getScoreInsight(String label, int score) {
    if (label == 'Productivity') {
      if (score > 80) return AppStrings.productivityInsightHigh;
      if (score > 50) return AppStrings.productivityInsightMed;
      return AppStrings.productivityInsightLow;
    } else {
      if (score > 80) return AppStrings.wellnessInsightHigh;
      if (score > 50) return AppStrings.wellnessInsightMed;
      return AppStrings.wellnessInsightLow;
    }
  }
}
