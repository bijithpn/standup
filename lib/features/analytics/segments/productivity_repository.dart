import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_aggregator.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight_engine.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

/// Reads the activity timeline and serves the rolled-up views the UI asks for.
///
/// Sits between the raw segment store and the screens so nothing in the
/// presentation layer holds a query or a thousand segments. Summaries are
/// cached per day and invalidated when new activity is written — the numbers
/// for a day that has already finished never change, and recomputing them on
/// every rebuild is the easiest way to make a dashboard feel slow.
class ProductivityRepository extends ChangeNotifier {
  ProductivityRepository({required ActivitySegmentRepository segments})
      : _segments = segments {
    _segments.addListener(_onSegmentsChanged);
  }

  final ActivitySegmentRepository _segments;

  final Map<String, DailyProductivitySummary> _dayCache =
      <String, DailyProductivitySummary>{};

  /// Aggregating more than this many days is moved off the UI thread.
  ///
  /// A single day is a few hundred segments and takes well under a frame;
  /// a month is worth the hop.
  static const int _isolateThresholdDays = 3;

  /// The day the cache must not trust, because it is still being written to.
  String? _volatileDate;

  void _onSegmentsChanged() {
    // New segments only ever affect the day they belong to, but the repository
    // does not know which that was — and the only day that can still be
    // growing is today.
    final today = dateKey(DateTime.now());
    _dayCache.remove(today);
    _volatileDate = today;
    notifyListeners();
  }

  /// `YYYY-MM-DD` for [time], the key segments are stored under.
  static String dateKey(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}'
      '-${time.day.toString().padLeft(2, '0')}';

  /// The summary for one day.
  DailyProductivitySummary summaryForDate(String date) {
    final cached = _dayCache[date];
    if (cached != null && date != _volatileDate) return cached;

    final summary = aggregateDay(date, _segments.segmentsForDate(date));
    _dayCache[date] = summary;
    if (date == _volatileDate) _volatileDate = null;
    return summary;
  }

  /// Today's summary.
  DailyProductivitySummary today({DateTime? now}) =>
      summaryForDate(dateKey(now ?? DateTime.now()));

  /// The drawable timeline for one day.
  List<TimelineEntry> timelineForDate(String date) =>
      buildTimeline(_segments.segmentsForDate(date));

  /// Every segment recorded for [appKey] on [date], for the app detail view.
  List<ActivitySegment> appSegments(String date, String appKey) {
    return _segments
        .segmentsForDate(date)
        .where((segment) =>
            segment.activityKind == ActivityKind.active &&
            segment.appKey == appKey)
        .toList(growable: false);
  }

  /// A rolled-up view of the last [days] days, ending today.
  ///
  /// Heavier ranges are aggregated on a background isolate: the segments are
  /// read here, because the store refuses access from anywhere else, and only
  /// the plain data crosses over.
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
      return aggregateRange(
        dates.map(summaryForDate).toList(growable: false),
      );
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
      dates.map((date) => _dayCache[date] ?? DailyProductivitySummary.empty(date))
          .toList(growable: false),
    );
  }

  /// The findings the recorded history supports, most trustworthy first.
  ///
  /// Returns empty when there is not enough history — the caller shows the
  /// "still learning" state rather than a list of hedged guesses.
  Future<List<ProductivityInsight>> insights({
    int historyDays = 14,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    final range = await summaryForLastDays(historyDays, now: moment);
    return generateInsights(
      range: range,
      today: summaryForDate(dateKey(moment)),
    );
  }

  /// Whether anything has been recorded at all.
  ///
  /// Drives the empty state: a dashboard of zeroes is worse than saying there
  /// is nothing yet.
  bool get hasAnyHistory => _segments.count() > 0;

  /// The days with recorded activity, newest first.
  List<String> recordedDates() => _segments.recordedDates();

  /// Forgets every cached summary. Called after history is cleared.
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

/// Isolate entry point: aggregate several days at once.
Map<String, DailyProductivitySummary> _aggregateDays(
  Map<String, List<ActivitySegment>> byDate,
) {
  return <String, DailyProductivitySummary>{
    for (final entry in byDate.entries)
      entry.key: aggregateDay(entry.key, entry.value),
  };
}
