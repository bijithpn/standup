import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// Time range selector shared by usage and focus queries.
enum UsagePeriod { today, week, month }

/// One app's accumulated foreground time for a period.
class AppUsageEntry {
  final String appKey;
  final String name;
  final AppCategory category;
  final int seconds;

  const AppUsageEntry({
    required this.appKey,
    required this.name,
    required this.category,
    required this.seconds,
  });
}

String formatUsageDuration(int seconds) {
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
