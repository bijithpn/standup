import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

/// Derives findings from recorded activity.
///
/// Pure functions over already-aggregated summaries, so this runs anywhere and
/// is testable without a database. Two rules hold throughout:
///
/// * Every finding is computed from real recorded time. Nothing is inferred to
///   fill a gap, and a thin week produces fewer insights rather than vaguer
///   ones.
/// * A finding that cannot clear [InsightEvidence.minimumDays] is not produced
///   at all. The dashboard says it is still learning, which is true.

/// The hour the afternoon is taken to begin, for before/after comparisons.
const int kAfternoonStartHour = 13;

/// A change smaller than this is noise, not a pattern worth reporting.
const double kMeaningfulChangeRatio = 0.2;

/// How much of the day must be active before the split is worth comparing.
const int kMinComparableSeconds = 30 * 60;

/// Generates every finding the data supports, most useful first.
///
/// [range] carries the history the patterns are drawn from; [today] is the day
/// being looked at, used for the observations that are about right now.
///
/// [focusGoalSeconds] is the daily focus goal, and [todayTimeline] the day's
/// stretches in order; both are optional and simply unlock more findings.
List<ProductivityInsight> generateInsights({
  required RangeProductivitySummary range,
  DailyProductivitySummary? today,
  int? focusGoalSeconds,
  List<TimelineEntry>? todayTimeline,
}) {
  final days = range.activeDayCount;
  final insights = <ProductivityInsight>[];

  // Today's observations stand on today's own data, so they do not need the
  // multi-day history the patterns do.
  if (today != null && today.hasActivity) {
    final busiest = _busiestApplication(today);
    if (busiest != null) insights.add(busiest);

    final idle = _idleShare(today);
    if (idle != null) insights.add(idle);

    final fragmented = _fragmentedDay(today);
    if (fragmented != null) insights.add(fragmented);

    final noBreak = _noBreakYet(today);
    if (noBreak != null) insights.add(noBreak);

    final stretch = _longestStretch(today, todayTimeline);
    if (stretch != null) insights.add(stretch);

    final pace = _goalProgress(today, focusGoalSeconds);
    if (pace != null) insights.add(pace);

    final usual = _comparedWithUsual(today, range);
    if (usual != null) insights.add(usual);
  }

  if (InsightEvidence.isSufficient(days)) {
    final focusWindow = _focusWindow(range);
    if (focusWindow != null) {
      insights
        ..add(focusWindow)
        ..addAll(_focusOpportunity(range, focusWindow));
    }

    final afternoonShift = _afternoonSwitching(range);
    if (afternoonShift != null) insights.add(afternoonShift);

    final breaks = _breakRhythm(range);
    if (breaks != null) insights.add(breaks);
  }

  // Strongest evidence first, so a hedged possibility never sits above a
  // finding the data actually supports.
  insights.sort((left, right) {
    // Evidence strength always leads, so a possibility never outranks a
    // measurement; priority then puts the actionable findings first.
    final byConfidence = left.confidence.index.compareTo(
      right.confidence.index,
    );
    if (byConfidence != 0) return byConfidence;
    final byPriority = right.priority.compareTo(left.priority);
    if (byPriority != 0) return byPriority;
    return right.evidenceDayCount.compareTo(left.evidenceDayCount);
  });

  return insights;
}

/// Whether there is enough recorded activity to say anything at all.
bool hasEnoughDataForInsights(RangeProductivitySummary range) =>
    InsightEvidence.isSufficient(range.activeDayCount);

// ── Today ───────────────────────────────────────────────────────────────────

ProductivityInsight? _busiestApplication(DailyProductivitySummary today) {
  final app = today.mostUsedApp;
  if (app == null || app.seconds < 5 * 60) return null;

  final share = today.activeSeconds == 0
      ? 0.0
      : app.seconds / today.activeSeconds;

  return ProductivityInsight(
    id: 'today-busiest-app',
    type: InsightType.applicationPattern,
    title: app.appName,
    description:
        '${_formatDuration(app.seconds)} today, '
        '${(share * 100).round()}% of your active time, '
        'across ${app.sessionCount} '
        '${app.sessionCount == 1 ? 'session' : 'sessions'}.',
    // A single day's own total is a measurement, not an extrapolation.
    confidence: InsightConfidence.high,
    evidenceDayCount: 1,
    supportingData: <String, Object>{
      'appKey': app.appKey,
      'seconds': app.seconds,
      'share': share,
      'sessions': app.sessionCount,
    },
  );
}

ProductivityInsight? _idleShare(DailyProductivitySummary today) {
  if (today.trackedSeconds < 60 * 60) return null;
  if (today.idleSeconds < 30 * 60) return null;

  final share = today.idleSeconds / today.trackedSeconds;
  if (share < 0.25) return null;

  return ProductivityInsight(
    id: 'today-idle',
    type: InsightType.idleTime,
    title: 'Away from the keyboard',
    description:
        '${_formatDuration(today.idleSeconds)} of the '
        '${_formatDuration(today.trackedSeconds)} tracked today was idle.',
    confidence: InsightConfidence.high,
    evidenceDayCount: 1,
    suggestion:
        'Time away from the screen is healthy rest. If you were not actually '
        'away, lower the idle time in General settings so it is not counted.',
    supportingData: <String, Object>{
      'idleSeconds': today.idleSeconds,
      'trackedSeconds': today.trackedSeconds,
      'share': share,
    },
  );
}

ProductivityInsight? _fragmentedDay(DailyProductivitySummary today) {
  if (today.activeSeconds < kMinComparableSeconds) return null;

  final rate = today.switchesPerActiveHour;
  if (rate < 10) return null;

  return ProductivityInsight(
    id: 'today-switching',
    type: InsightType.contextSwitching,
    title: 'Context switching',
    description:
        '${today.contextSwitches} application switches today, '
        'about ${rate.toStringAsFixed(1)} an hour.',
    confidence: InsightConfidence.high,
    evidenceDayCount: 1,
    priority: 50,
    suggestion:
        'Try batching chat and email into two or three set times, and close '
        'the apps you are not using for the next hour.',
    supportingData: <String, Object>{
      'switches': today.contextSwitches,
      'perHour': rate,
    },
  );
}

/// Working a long time with no break at all today.
ProductivityInsight? _noBreakYet(DailyProductivitySummary today) {
  if (today.breakSeconds > 0) return null;
  if (today.activeSeconds < 90 * 60) return null;

  return ProductivityInsight(
    id: 'today-no-break',
    type: InsightType.breakPattern,
    title: 'No break yet today',
    description:
        'You have worked ${_formatDuration(today.activeSeconds)} without a '
        'break.',
    confidence: InsightConfidence.high,
    evidenceDayCount: 1,
    priority: 100,
    suggestion:
        'Stand up for five minutes now. Short, regular breaks keep focus '
        'higher for the rest of the day.',
    supportingData: <String, Object>{'activeSeconds': today.activeSeconds},
  );
}

/// How long the longest unbroken stretch of work was.
ProductivityInsight? _longestStretch(
  DailyProductivitySummary today,
  List<TimelineEntry>? timeline,
) {
  if (timeline == null || timeline.isEmpty) return null;

  var longest = 0;
  for (final entry in timeline) {
    if (entry.kind == ActivityKind.active && entry.seconds > longest) {
      longest = entry.seconds;
    }
  }

  if (longest >= 75 * 60) {
    return ProductivityInsight(
      id: 'today-long-stretch',
      type: InsightType.breakPattern,
      title: 'A very long stretch',
      description:
          'Your longest run today was ${_formatDuration(longest)} in one '
          'app without stopping.',
      confidence: InsightConfidence.high,
      evidenceDayCount: 1,
      priority: 90,
      suggestion:
          'Aim for a pause about every 50–60 minutes. You will keep your '
          'edge longer and your eyes and back will thank you.',
      supportingData: <String, Object>{'longestSeconds': longest},
    );
  }

  // Plenty of time at the computer, but never more than a short burst at once.
  if (today.activeSeconds >= 60 * 60 && longest < 20 * 60) {
    return ProductivityInsight(
      id: 'today-short-bursts',
      type: InsightType.contextSwitching,
      title: 'Focus in short bursts',
      description:
          'You were active for ${_formatDuration(today.activeSeconds)}, but '
          'your longest uninterrupted stretch was ${_formatDuration(longest)}.',
      confidence: InsightConfidence.high,
      evidenceDayCount: 1,
      priority: 70,
      suggestion:
          'Try one 25-minute block on a single task with notifications off, '
          'then take a short break.',
      supportingData: <String, Object>{'longestSeconds': longest},
    );
  }
  return null;
}

/// How far today is from the daily focus goal.
ProductivityInsight? _goalProgress(
  DailyProductivitySummary today,
  int? goalSeconds,
) {
  if (goalSeconds == null || goalSeconds <= 0) return null;
  if (today.activeSeconds < 10 * 60) return null;

  if (today.activeSeconds >= goalSeconds) {
    return ProductivityInsight(
      id: 'today-goal-reached',
      type: InsightType.goalProgress,
      title: 'Goal reached',
      description:
          'You have reached today\'s ${_formatDuration(goalSeconds)} focus '
          'goal with ${_formatDuration(today.activeSeconds)}.',
      confidence: InsightConfidence.high,
      evidenceDayCount: 1,
      priority: 80,
      suggestion:
          'Nicely done. Anything more today is a bonus — it is fine to wind '
          'down.',
      supportingData: <String, Object>{'activeSeconds': today.activeSeconds},
    );
  }

  final left = goalSeconds - today.activeSeconds;
  final percent = (today.activeSeconds / goalSeconds * 100).round();
  return ProductivityInsight(
    id: 'today-goal-progress',
    type: InsightType.goalProgress,
    title: '$percent% of today\'s goal',
    description:
        '${_formatDuration(today.activeSeconds)} done, '
        '${_formatDuration(left)} to go to reach '
        '${_formatDuration(goalSeconds)}.',
    confidence: InsightConfidence.high,
    evidenceDayCount: 1,
    priority: 60,
    supportingData: <String, Object>{
      'activeSeconds': today.activeSeconds,
      'leftSeconds': left,
    },
  );
}

/// Today set against the user's own usual day.
ProductivityInsight? _comparedWithUsual(
  DailyProductivitySummary today,
  RangeProductivitySummary range,
) {
  final others = range.days
      .where((d) => d.hasActivity && d.date != today.date)
      .toList();
  if (others.length < InsightEvidence.minimumDays) return null;
  if (today.activeSeconds < 20 * 60) return null;

  final usual =
      others.fold<int>(0, (sum, d) => sum + d.activeSeconds) ~/ others.length;
  if (usual <= 0) return null;

  final change = (today.activeSeconds - usual) / usual;
  if (change.abs() < kMeaningfulChangeRatio) return null;

  final more = change > 0;
  final percent = (change.abs() * 100).round();
  final confidence = InsightEvidence.forDays(others.length);

  return ProductivityInsight(
    id: 'today-vs-usual',
    type: InsightType.comparison,
    title: more ? 'A busier day than usual' : 'A lighter day than usual',
    description:
        'So far today you have been active '
        '${_formatDuration(today.activeSeconds)} — $percent% '
        '${more ? 'more' : 'less'} than your usual '
        '${_formatDuration(usual)} a day.',
    confidence: confidence,
    evidenceDayCount: others.length,
    priority: 40,
    suggestion: more
        ? 'Make sure you are taking your breaks — busy days are when they '
              'matter most.'
        : null,
    supportingData: <String, Object>{
      'todaySeconds': today.activeSeconds,
      'usualSeconds': usual,
    },
  );
}

// ── Patterns across days ────────────────────────────────────────────────────

/// The stretch of the day that consistently holds the most active time.
///
/// Averaged across days rather than summed, so a single long Tuesday cannot
/// pass itself off as a habit.
ProductivityInsight? _focusWindow(RangeProductivitySummary range) {
  final activeDays = range.days.where((day) => day.hasActivity).toList();
  if (!InsightEvidence.isSufficient(activeDays.length)) return null;

  final averagePerHour = List<double>.filled(24, 0);
  for (final day in activeDays) {
    for (var hour = 0; hour < 24; hour++) {
      averagePerHour[hour] += day.hourlyActiveSeconds[hour] / activeDays.length;
    }
  }

  // A three-hour window: long enough to be a working block, short enough to be
  // advice rather than a description of the whole day.
  const windowHours = 3;
  var bestStart = -1;
  var bestSeconds = 0.0;
  for (var start = 0; start + windowHours <= 24; start++) {
    var total = 0.0;
    for (var offset = 0; offset < windowHours; offset++) {
      total += averagePerHour[start + offset];
    }
    if (total > bestSeconds) {
      bestSeconds = total;
      bestStart = start;
    }
  }

  // Under twenty minutes a day in the best window means there is no shape to
  // the day yet, only scattered minutes.
  if (bestStart < 0 || bestSeconds < 20 * 60) return null;

  final confidence = InsightEvidence.forDays(activeDays.length);
  final window =
      '${_formatHour(bestStart)}–${_formatHour(bestStart + windowHours)}';

  return ProductivityInsight(
    id: 'focus-window',
    type: InsightType.focusWindow,
    title: 'Your busiest hours',
    description: confidence.isAssertable
        ? 'Most of your active time falls between $window, averaging '
              '${_formatDuration(bestSeconds.round())} a day.'
        : 'Your active time so far leans toward $window.',
    confidence: confidence,
    evidenceDayCount: activeDays.length,
    supportingData: <String, Object>{
      'startHour': bestStart,
      'endHour': bestStart + windowHours,
      'averageSeconds': bestSeconds.round(),
    },
  );
}

/// Turns the focus window into something to do about it.
List<ProductivityInsight> _focusOpportunity(
  RangeProductivitySummary range,
  ProductivityInsight window,
) {
  // Only worth suggesting once the window is trustworthy enough to plan around.
  if (window.confidence == InsightConfidence.low) {
    return const <ProductivityInsight>[];
  }

  final startHour = window.supportingData['startHour'] as int;
  final endHour = window.supportingData['endHour'] as int;

  return <ProductivityInsight>[
    ProductivityInsight(
      id: 'focus-opportunity',
      type: InsightType.focusOpportunity,
      title: 'Protect your best hours',
      description:
          'You are most active between '
          '${_formatHour(startHour)} and ${_formatHour(endHour)}. '
          'Work you care about tends to go better scheduled here.',
      confidence: window.confidence,
      evidenceDayCount: window.evidenceDayCount,
      suggestion:
          'Put your hardest task in ${_formatHour(startHour)}–'
          '${_formatHour(endHour)} and keep meetings out of it.',
      supportingData: window.supportingData,
    ),
  ];
}

/// Whether attention fragments after lunch, compared with the morning.
ProductivityInsight? _afternoonSwitching(RangeProductivitySummary range) {
  final activeDays = range.days.where((day) => day.hasActivity).toList();
  if (!InsightEvidence.isSufficient(activeDays.length)) return null;

  final mornings = <double>[];
  final afternoons = <double>[];
  for (final day in activeDays) {
    final morning = day.switchRateBetween(0, kAfternoonStartHour);
    final afternoon = day.switchRateBetween(kAfternoonStartHour, 24);
    // Only days with enough of both halves can contribute to the comparison.
    if (morning == null || afternoon == null) continue;
    mornings.add(morning);
    afternoons.add(afternoon);
  }

  if (!InsightEvidence.isSufficient(mornings.length)) return null;

  final morningRate = mornings.reduce((a, b) => a + b) / mornings.length;
  final afternoonRate = afternoons.reduce((a, b) => a + b) / afternoons.length;

  final confidence = InsightEvidence.forDays(mornings.length);

  // An undisturbed morning is the most interesting version of this finding,
  // and also the one a percentage cannot express — there is nothing to divide
  // by. Report the two rates directly instead of discarding the comparison.
  if (morningRate <= 0) {
    if (afternoonRate < 1) return null;
    return ProductivityInsight(
      id: 'afternoon-switching',
      type: InsightType.contextSwitching,
      title: 'Afternoon focus',
      description: confidence.isAssertable
          ? 'Your mornings run without switching applications, while '
                'afternoons average ${afternoonRate.toStringAsFixed(1)} switches '
                'an hour.'
          : 'Your mornings so far have run without switching applications, '
                'unlike your afternoons.',
      confidence: confidence,
      evidenceDayCount: mornings.length,
      supportingData: <String, Object>{
        'morningPerHour': morningRate,
        'afternoonPerHour': afternoonRate,
        'change': double.infinity,
      },
    );
  }

  final change = (afternoonRate - morningRate) / morningRate;
  if (change.abs() < kMeaningfulChangeRatio) return null;

  final percent = (change.abs() * 100).round();
  final direction = change > 0 ? 'higher' : 'lower';

  return ProductivityInsight(
    id: 'afternoon-switching',
    type: InsightType.contextSwitching,
    title: 'Afternoon focus',
    description: confidence.isAssertable
        ? 'Your context switching runs $percent% $direction after '
              '${_formatHour(kAfternoonStartHour)} than in the morning.'
        : 'Your afternoons appear to carry $percent% $direction context '
              'switching than your mornings.',
    confidence: confidence,
    evidenceDayCount: mornings.length,
    supportingData: <String, Object>{
      'morningPerHour': morningRate,
      'afternoonPerHour': afternoonRate,
      'change': change,
    },
  );
}

/// How much of the working day is actually spent on breaks.
ProductivityInsight? _breakRhythm(RangeProductivitySummary range) {
  final activeDays = range.days.where((day) => day.hasActivity).toList();
  if (!InsightEvidence.isSufficient(activeDays.length)) return null;

  final withBreaks = activeDays.where((day) => day.breakSeconds > 0).length;
  if (withBreaks == 0) return null;

  final averageBreakSeconds = range.breakSeconds ~/ activeDays.length;
  final averageActiveSeconds = range.averageActiveSecondsPerDay;
  if (averageActiveSeconds <= 0) return null;

  final confidence = InsightEvidence.forDays(activeDays.length);

  return ProductivityInsight(
    id: 'break-rhythm',
    type: InsightType.breakPattern,
    title: 'Break rhythm',
    description: confidence.isAssertable
        ? 'You average ${_formatDuration(averageBreakSeconds)} of breaks '
              'against ${_formatDuration(averageActiveSeconds)} of active time '
              'a day.'
        : 'So far you are averaging ${_formatDuration(averageBreakSeconds)} '
              'of breaks a day.',
    confidence: confidence,
    evidenceDayCount: activeDays.length,
    supportingData: <String, Object>{
      'averageBreakSeconds': averageBreakSeconds,
      'averageActiveSeconds': averageActiveSeconds,
      'daysWithBreaks': withBreaks,
    },
  );
}

// ── Formatting ──────────────────────────────────────────────────────────────

String _formatDuration(int seconds) {
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatHour(int hour) {
  final wrapped = hour % 24;
  final suffix = wrapped < 12 ? 'am' : 'pm';
  final display = wrapped % 12 == 0 ? 12 : wrapped % 12;
  return '$display$suffix';
}
