/// The break-before-meeting skip correlation — the one time-pattern finding
/// sketched for §7.2/Phase 4 that shipped separately once timestamped
/// meeting history was needed (only [CalendarFocusComparison]'s caller
/// already fetches that via `CalendarService.getEvents`). See the
/// workflow-analysis plan doc §7.6.
library;

import 'package:breakmate/features/analytics/break_history_service.dart';

/// A break counts as "before a meeting" if a calendar event starts within
/// this many minutes after the break's scheduled time.
const int meetingProximityWindowMinutes = 15;

/// Minimum sample size on each side before the comparison is trusted enough
/// to surface — same standard as [CalendarFocusComparison.minComparisonDays].
const int minMeetingProximitySamples = 3;

/// Compares the skip rate of breaks that fell shortly before a meeting
/// against breaks that didn't, to answer: does a meeting on the horizon make
/// you more likely to skip your break?
class MeetingBreakCorrelation {
  final int nearMeetingCount;
  final int nearMeetingSkipped;
  final int otherCount;
  final int otherSkipped;

  const MeetingBreakCorrelation({
    required this.nearMeetingCount,
    required this.nearMeetingSkipped,
    required this.otherCount,
    required this.otherSkipped,
  });

  double get nearMeetingSkipRate =>
      nearMeetingCount == 0 ? 0.0 : nearMeetingSkipped / nearMeetingCount;

  double get otherSkipRate =>
      otherCount == 0 ? 0.0 : otherSkipped / otherCount;

  bool get hasEnoughData =>
      nearMeetingCount >= minMeetingProximitySamples &&
      otherCount >= minMeetingProximitySamples;

  /// Percentage-point gap; positive means breaks before a meeting get
  /// skipped more often.
  double get skipRateDeltaPoints =>
      (nearMeetingSkipRate - otherSkipRate) * 100;

  String describe() {
    final delta = skipRateDeltaPoints;
    final direction = delta >= 0 ? 'more' : 'less';
    return "You skip breaks right before a meeting "
        "${delta.abs().round()}% $direction often than other breaks.";
  }

  /// Buckets [breakEvents] by whether a meeting in [meetingStartTimes] began
  /// within [meetingProximityWindowMinutes] after the break, then compares
  /// skip rates between the two buckets.
  static MeetingBreakCorrelation compute({
    required List<BreakEvent> breakEvents,
    required List<DateTime> meetingStartTimes,
  }) {
    var nearMeetingCount = 0;
    var nearMeetingSkipped = 0;
    var otherCount = 0;
    var otherSkipped = 0;

    for (final event in breakEvents) {
      final isNearMeeting = meetingStartTimes.any((meetingStart) {
        final diff = meetingStart.difference(event.time).inMinutes;
        return diff >= 0 && diff <= meetingProximityWindowMinutes;
      });

      if (isNearMeeting) {
        nearMeetingCount++;
        if (!event.completed) nearMeetingSkipped++;
      } else {
        otherCount++;
        if (!event.completed) otherSkipped++;
      }
    }

    return MeetingBreakCorrelation(
      nearMeetingCount: nearMeetingCount,
      nearMeetingSkipped: nearMeetingSkipped,
      otherCount: otherCount,
      otherSkipped: otherSkipped,
    );
  }
}
