import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/app_icon_cache.dart';
import 'package:breakmate/features/analytics/app_usage_insights.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

class AppUsageSection extends StatelessWidget {
  final bool enabled;
  final List<AppUsageEntry> topApps;
  final Map<AppCategory, int> categoryTotals;
  final AppIconCache iconCache;
  final VoidCallback onEnable;

  /// Heading for the app list. Defaults to 'Top Apps' (a highlights view);
  /// pass e.g. 'All Tracked Apps' when [topApps] holds the complete,
  /// unfiltered list rather than a cut-off top N.
  final String listTitle;

  /// The user's opt-in daily budgets (`SettingsModel.categoryDailyBudgetMinutes`).
  /// Only meaningful when [categoryTotals] is for today — pass `const {}`
  /// (the default) for week/month views, where "over budget" doesn't apply.
  final Map<String, int> budgetMinutes;

  const AppUsageSection({
    super.key,
    required this.enabled,
    required this.topApps,
    required this.categoryTotals,
    required this.iconCache,
    required this.onEnable,
    this.listTitle = 'Top Apps',
    this.budgetMinutes = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return _buildDisabledState();
    if (topApps.isEmpty) return _buildEmptyState();
    return _buildPopulatedState();
  }

  Widget _buildDisabledState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.app_badge,
                size: 20,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                'App Usage',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'See which apps you spend time in — like Digital Wellbeing. '
            'Only app names and time spent are stored, locally.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          MinimalButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            backgroundColor: AppTheme.accentColor,
            borderRadius: BorderRadius.circular(8),
            onPressed: onEnable,
            child: const Text(
              'Enable',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Text(
        'Still gathering data for this period — check back in a bit.',
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildPopulatedState() {
    final dominant = _dominantCategory();
    final totalSeconds = categoryTotals.values.fold<int>(
      0,
      (sum, s) => sum + s,
    );
    final tip = usageTip(dominant, totalSeconds ~/ 60);
    final maxSeconds = topApps.first.seconds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                listTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${topApps.length} app${topApps.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...topApps.map((entry) => _buildAppRow(entry, maxSeconds)),
          const SizedBox(height: 16),
          Text(
            'By Category',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in AppCategory.values)
                if ((categoryTotals[category] ?? 0) > 0)
                  _buildCategoryChip(
                    category,
                    categoryTotals[category]!,
                    totalSeconds,
                  ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.lightbulb,
                  size: 16,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._buildBudgetNudge(),
        ],
      ),
    );
  }

  List<Widget> _buildBudgetNudge() {
    if (budgetMinutes.isEmpty) return const [];
    final overBudget = categoriesOverBudget(
      todayCategorySeconds: categoryTotals,
      budgetMinutes: budgetMinutes,
    );
    if (overBudget.isEmpty) return const [];

    final names = overBudget.map((c) => c.label).join(', ');
    return [
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.timer, size: 16, color: AppTheme.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You've reached today's budget for $names. Just a note — nothing is blocked.",
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  AppCategory _dominantCategory() {
    var dominant = AppCategory.general;
    var max = -1;
    for (final entry in categoryTotals.entries) {
      if (entry.value > max) {
        max = entry.value;
        dominant = entry.key;
      }
    }
    return dominant;
  }

  Widget _buildAppRow(AppUsageEntry entry, int maxSeconds) {
    final fraction = maxSeconds > 0 ? entry.seconds / maxSeconds : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _buildIcon(entry),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.05, 1.0),
                    minHeight: 4,
                    backgroundColor: entry.category.color.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: AlwaysStoppedAnimation(entry.category.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatUsageDuration(entry.seconds),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(AppUsageEntry entry) {
    return FutureBuilder<Uint8List?>(
      future: iconCache.iconFor(appKey: entry.appKey, bundleId: entry.appKey),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          );
        }
        return _buildInitialsAvatar(entry.name, entry.category.color);
      },
    );
  }

  Widget _buildInitialsAvatar(String name, Color color) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    AppCategory category,
    int seconds,
    int totalSeconds,
  ) {
    final percent = totalSeconds > 0
        ? (seconds / totalSeconds * 100).round()
        : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 12, color: category.color),
          const SizedBox(width: 6),
          Text(
            '${category.label} · ${formatUsageDuration(seconds)} ($percent%)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}
