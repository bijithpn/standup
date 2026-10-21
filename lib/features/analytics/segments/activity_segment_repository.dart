import 'package:flutter/foundation.dart';

import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/objectbox.g.dart';

/// Stores and reads the activity timeline.
///
/// Writes are batched: the tracker produces a segment every time the active app
/// changes, and committing each one individually would mean a transaction every
/// few seconds all day. Segments are buffered and flushed together instead.
///
/// Every method is safe to call when storage is unavailable — productivity
/// tracking failing must never take BreakMate down with it.
class ActivitySegmentRepository extends ChangeNotifier {
  ActivitySegmentRepository({
    required StorageService storage,
    AppLogger? logger,
    this.flushThreshold = 8,
  })  : _storage = storage,
        _logger = logger ?? AppLogger();

  final StorageService _storage;
  final AppLogger _logger;

  /// How many segments accumulate before a write. A context switch every few
  /// seconds is the busy case, so this is a handful of minutes of activity.
  final int flushThreshold;

  final List<ActivitySegment> _pending = <ActivitySegment>[];

  Box<ActivitySegment>? get _box => _storage.activitySegmentBox;

  /// Segments recorded but not yet written. Visible for tests.
  @visibleForTesting
  int get pendingCount => _pending.length;

  /// Queues [segment] for storage.
  void record(ActivitySegment segment) {
    if (!segment.isValid) return;
    _pending.add(segment);
    if (_pending.length >= flushThreshold) flush();
  }

  /// Writes everything buffered. Called on the flush timer, when tracking
  /// stops, and before the app shuts down.
  void flush() {
    if (_pending.isEmpty) return;

    final box = _box;
    if (box == null) {
      // Storage is not open yet. Hold the segments rather than dropping them,
      // but do not let the buffer grow without bound if it never opens.
      if (_pending.length > 500) {
        _pending.removeRange(0, _pending.length - 500);
      }
      return;
    }

    try {
      box.putMany(List<ActivitySegment>.of(_pending));
      _pending.clear();
      notifyListeners();
    } catch (e) {
      _logger.error('ActivitySegmentRepository flush failed: $e');
    }
  }

  /// Every segment on [date] (`YYYY-MM-DD`), oldest first.
  List<ActivitySegment> segmentsForDate(String date) {
    final box = _box;
    if (box == null) return const <ActivitySegment>[];

    try {
      final query = box
          .query(ActivitySegment_.date.equals(date))
          .order(ActivitySegment_.startedAtMs)
          .build();
      try {
        return query.find();
      } finally {
        query.close();
      }
    } catch (e) {
      _logger.error('ActivitySegmentRepository read failed: $e');
      return const <ActivitySegment>[];
    }
  }

  /// Every segment between [from] and [to] inclusive, oldest first.
  List<ActivitySegment> segmentsBetween(DateTime from, DateTime to) {
    final box = _box;
    if (box == null) return const <ActivitySegment>[];

    final startMs = DateTime(from.year, from.month, from.day)
        .millisecondsSinceEpoch;
    final endMs = DateTime(to.year, to.month, to.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    try {
      final query = box
          .query(ActivitySegment_.startedAtMs.between(startMs, endMs))
          .order(ActivitySegment_.startedAtMs)
          .build();
      try {
        return query.find();
      } finally {
        query.close();
      }
    } catch (e) {
      _logger.error('ActivitySegmentRepository range read failed: $e');
      return const <ActivitySegment>[];
    }
  }

  /// The days that have any recorded activity, newest first.
  List<String> recordedDates() {
    final box = _box;
    if (box == null) return const <String>[];

    try {
      final dates = <String>{};
      for (final segment in box.getAll()) {
        dates.add(segment.date);
      }
      return dates.toList()..sort((a, b) => b.compareTo(a));
    } catch (e) {
      _logger.error('ActivitySegmentRepository dates read failed: $e');
      return const <String>[];
    }
  }

  /// Applies the user's retention window, at most once a day.
  ///
  /// [retentionDays] of 0 means keep everything. Self-throttling because this
  /// is called from the flush timer, and a delete query every 30 seconds to
  /// find nothing is pure waste.
  void applyRetention(int retentionDays, {DateTime? now}) {
    if (retentionDays <= 0) return;

    final today = now ?? DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    if (_lastRetentionDay == todayKey) return;
    _lastRetentionDay = todayKey;

    pruneBefore(
      DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: retentionDays)),
    );
  }

  String? _lastRetentionDay;

  /// Deletes segments that started before [cutoff].
  ///
  /// Returns how many were removed.
  int pruneBefore(DateTime cutoff) {
    final box = _box;
    if (box == null) return 0;

    try {
      final query =
          box.query(ActivitySegment_.startedAtMs.lessThan(
        cutoff.millisecondsSinceEpoch,
      )).build();
      try {
        final removed = query.remove();
        if (removed > 0) {
          _logger.info('Pruned $removed activity segments before $cutoff');
          notifyListeners();
        }
        return removed;
      } finally {
        query.close();
      }
    } catch (e) {
      _logger.error('ActivitySegmentRepository prune failed: $e');
      return 0;
    }
  }

  /// Deletes the entire activity history. Used by the "clear history" action,
  /// which is destructive and always confirmed before it reaches here.
  int clearAll() {
    _pending.clear();
    final box = _box;
    if (box == null) return 0;

    try {
      final removed = box.removeAll();
      _logger.info('Cleared $removed activity segments');
      notifyListeners();
      return removed;
    } catch (e) {
      _logger.error('ActivitySegmentRepository clear failed: $e');
      return 0;
    }
  }

  /// How many segments are stored. Used by the privacy screen to tell the user
  /// what "clear history" would actually delete.
  int count() {
    final box = _box;
    if (box == null) return 0;
    try {
      return box.count();
    } catch (e) {
      _logger.error('ActivitySegmentRepository count failed: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    flush();
    super.dispose();
  }
}
