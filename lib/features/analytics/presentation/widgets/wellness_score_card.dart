import 'package:flutter/cupertino.dart';
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
        const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  letterSpacing: 1.0,
                  fontFamily: 'Inter',
                ),
              ),
              Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fillWidth =
                  (constraints.maxWidth * (score / 100).clamp(0.03, 1.0));
              return Stack(
                children: [
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    height: 4,
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _getScoreInsight(label, score),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
              height: 1.2,
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
