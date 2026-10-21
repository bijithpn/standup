import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

enum UsagePeriod { today, week, month }

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

/// Formats a duration in seconds as e.g. "1h 24m", "45m", or "0m".
String formatUsageDuration(int seconds) {
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
