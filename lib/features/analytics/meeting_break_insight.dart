library;

import 'package:breakmate/features/analytics/break_history_service.dart';

const int meetingProximityWindowMinutes = 15;

const int minMeetingProximitySamples = 3;

/// Compares skip rate of breaks within 15 min before a meeting vs other breaks.
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

  double get otherSkipRate => otherCount == 0 ? 0.0 : otherSkipped / otherCount;

  bool get hasEnoughData =>
      nearMeetingCount >= minMeetingProximitySamples &&
      otherCount >= minMeetingProximitySamples;

  double get skipRateDeltaPoints => (nearMeetingSkipRate - otherSkipRate) * 100;

  String describe() {
    final delta = skipRateDeltaPoints;
    final direction = delta >= 0 ? 'more' : 'less';
    return "You skip breaks right before a meeting "
        "${delta.abs().round()}% $direction often than other breaks.";
  }

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
