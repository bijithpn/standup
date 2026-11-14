import 'package:flutter/foundation.dart';

import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/objectbox.g.dart';

/// Buffers segments in memory and batch-writes them to ObjectBox; backs the activity timeline and retention pruning.
class ActivitySegmentRepository extends ChangeNotifier {
  ActivitySegmentRepository({
    required StorageService storage,
    AppLogger? logger,
    this.flushThreshold = 8,
  }) : _storage = storage,
       _logger = logger ?? AppLogger();

  final StorageService _storage;
  final AppLogger _logger;

  final int flushThreshold;

  final List<ActivitySegment> _pending = <ActivitySegment>[];

  Box<ActivitySegment>? get _box => _storage.activitySegmentBox;

  @visibleForTesting
  int get pendingCount => _pending.length;

  void record(ActivitySegment segment) {
    if (!segment.isValid) return;
    _pending.add(segment);
    if (_pending.length >= flushThreshold) flush();
  }

  void flush() {
    if (_pending.isEmpty) return;

    final box = _box;
    if (box == null) {
      // DB unavailable: keep only the newest 500 so memory stays bounded.
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

  List<ActivitySegment> segmentsBetween(DateTime from, DateTime to) {
    final box = _box;
    if (box == null) return const <ActivitySegment>[];

    final startMs = DateTime(
      from.year,
      from.month,
      from.day,
    ).millisecondsSinceEpoch;
    final endMs = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

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

  void applyRetention(int retentionDays, {DateTime? now}) {
    if (retentionDays <= 0) return;

    final today = now ?? DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    if (_lastRetentionDay == todayKey) return;
    _lastRetentionDay = todayKey;

    pruneBefore(
      DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: retentionDays)),
    );
  }

  String? _lastRetentionDay;

  int pruneBefore(DateTime cutoff) {
    final box = _box;
    if (box == null) return 0;

    try {
      final query = box
          .query(
            ActivitySegment_.startedAtMs.lessThan(
              cutoff.millisecondsSinceEpoch,
            ),
          )
          .build();
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
