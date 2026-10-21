// lib/features/analytics/app_usage_insights.dart
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// One-line insight for the App Usage section's tip card, based on the
/// period's dominant category. Mirrors the tone of
/// WellnessEngine.getSuggestedBreakTip's per-category tips.
String usageTip(AppCategory dominant, int totalMinutes) {
  switch (dominant) {
    case AppCategory.coding:
      return "You've spent a lot of time coding — remember good posture and take a stretch break.";
    case AppCategory.writing:
      return "Lots of typing today — shake out your hands and stretch your forearms now and then.";
    case AppCategory.browsing:
      return "You're spending a lot of time browsing — try the 20-20-20 rule to rest your eyes.";
    case AppCategory.meeting:
      return "Back-to-back meetings today — take 3 deep breaths and stand up between calls.";
    case AppCategory.design:
      return "Deep design focus — gently tilt your head side to side to release neck tension.";
    case AppCategory.general:
      return "Nice, balanced day so far. Keep taking your scheduled breaks.";
  }
}

/// Categories whose usage today has met or exceeded the user's own
/// [SettingsModel.categoryDailyBudgetMinutes] for that category. Purely
/// informational — [AppUsageSection] surfaces this as a soft nudge line,
/// nothing here ever blocks or restricts anything, and a category absent
/// from [budgetMinutes] (or set to 0) has no budget and is never included.
List<AppCategory> categoriesOverBudget({
  required Map<AppCategory, int> todayCategorySeconds,
  required Map<String, int> budgetMinutes,
}) {
  final result = <AppCategory>[];
  for (final entry in budgetMinutes.entries) {
    if (entry.value <= 0) continue;
    final category = AppCategory.values.firstWhere(
      (c) => c.name == entry.key,
      orElse: () => AppCategory.general,
    );
    final usedMinutes = (todayCategorySeconds[category] ?? 0) ~/ 60;
    if (usedMinutes >= entry.value) result.add(category);
  }
  return result;
}
