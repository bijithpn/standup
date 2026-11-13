import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_aggregator.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight_engine.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

/// Cached read model over activity segments: daily/range summaries, timelines and insights for the productivity page.
class ProductivityRepository extends ChangeNotifier {
  ProductivityRepository({required ActivitySegmentRepository segments})
    : _segments = segments {
    _segments.addListener(_onSegmentsChanged);
  }

  final ActivitySegmentRepository _segments;

  final Map<String, DailyProductivitySummary> _dayCache =
      <String, DailyProductivitySummary>{};

  static const int _isolateThresholdDays = 3;

  String? _volatileDate;

  // New segments only change today's data, so only today's cached summary is invalidated.
  void _onSegmentsChanged() {
    final today = dateKey(DateTime.now());
    _dayCache.remove(today);
    _volatileDate = today;
    notifyListeners();
  }

  void refreshToday() {
    _segments.flush();
    invalidate();
  }

  static String dateKey(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}'
      '-${time.day.toString().padLeft(2, '0')}';

  DailyProductivitySummary summaryForDate(String date) {
    final cached = _dayCache[date];
    if (cached != null && date != _volatileDate) return cached;

    final summary = aggregateDay(date, _segments.segmentsForDate(date));
    _dayCache[date] = summary;
    if (date == _volatileDate) _volatileDate = null;
    return summary;
  }

  DailyProductivitySummary today({DateTime? now}) =>
      summaryForDate(dateKey(now ?? DateTime.now()));

  List<TimelineEntry> timelineForDate(String date) =>
      buildTimeline(_segments.segmentsForDate(date));

  List<ActivitySegment> appSegments(String date, String appKey) {
    return _segments
        .segmentsForDate(date)
        .where(
          (segment) =>
              segment.activityKind == ActivityKind.active &&
              segment.appKey == appKey,
        )
        .toList(growable: false);
  }

  /// Ranges over a few days aggregate inline; larger ones aggregate uncached days in a background isolate.
  Future<RangeProductivitySummary> summaryForLastDays(
    int days, {
    DateTime? now,
  }) async {
    if (days <= 0) return RangeProductivitySummary.empty();

    final end = now ?? DateTime.now();
    final dates = <String>[
      for (var offset = days - 1; offset >= 0; offset--)
        dateKey(end.subtract(Duration(days: offset))),
    ];

    if (days <= _isolateThresholdDays) {
      return aggregateRange(dates.map(summaryForDate).toList(growable: false));
    }

    final uncached = dates
        .where((date) => _dayCache[date] == null || date == _volatileDate)
        .toList(growable: false);

    if (uncached.isNotEmpty) {
      final byDate = <String, List<ActivitySegment>>{
        for (final date in uncached) date: _segments.segmentsForDate(date),
      };

      final computed = await compute(_aggregateDays, byDate);
      _dayCache.addAll(computed);
      _volatileDate = null;
    }

    return aggregateRange(
      dates
          .map(
            (date) => _dayCache[date] ?? DailyProductivitySummary.empty(date),
          )
          .toList(growable: false),
    );
  }

  Future<List<ProductivityInsight>> insights({
    int historyDays = 14,
    DateTime? now,
    int? focusGoalSeconds,
  }) async {
    final moment = now ?? DateTime.now();
    final range = await summaryForLastDays(historyDays, now: moment);
    final todayKey = dateKey(moment);
    return generateInsights(
      range: range,
      today: summaryForDate(todayKey),
      focusGoalSeconds: focusGoalSeconds,
      todayTimeline: timelineForDate(todayKey),
    );
  }

  bool get hasAnyHistory => _segments.count() > 0;

  List<String> recordedDates() => _segments.recordedDates();

  void invalidate() {
    _dayCache.clear();
    _volatileDate = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _segments.removeListener(_onSegmentsChanged);
    super.dispose();
  }
}

Map<String, DailyProductivitySummary> _aggregateDays(
  Map<String, List<ActivitySegment>> byDate,
) {
  return <String, DailyProductivitySummary>{
    for (final entry in byDate.entries)
      entry.key: aggregateDay(entry.key, entry.value),
  };
}
