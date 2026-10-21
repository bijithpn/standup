import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/storage_service.dart';

/// One completed or skipped break, with the timestamp it ended at.
class BreakEvent {
  final DateTime time;
  final bool completed;

  const BreakEvent({required this.time, required this.completed});

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'completed': completed,
  };

  factory BreakEvent.fromJson(Map<String, dynamic> json) {
    return BreakEvent(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime(0),
      completed: json['completed'] as bool? ?? false,
    );
  }
}

/// Local, timestamped break history — separate from [StatsService]'s daily
/// counters, which don't record *when* each break happened. Exists so break
/// timing can be correlated against other timestamped data (e.g. focus
/// sessions) rather than just compared day-to-day. Same pruned-JSON-blob
/// shape as [AppUsageService]/[FocusSessionService].
class BreakHistoryService extends ChangeNotifier {
  static const _maxAgeDays = 30;

  final StorageService _storage;
  final List<BreakEvent> _events = [];

  BreakHistoryService({required StorageService storage}) : _storage = storage {
    _load();
  }

  void recordBreak({required DateTime time, required bool completed}) {
    _events.add(BreakEvent(time: time, completed: completed));
    _prune();
    _persist();
    notifyListeners();
  }

  List<BreakEvent> get events => List.unmodifiable(_events);

  /// Events whose timestamp falls within `[start, end)`.
  List<BreakEvent> eventsBetween(DateTime start, DateTime end) {
    return _events
        .where((e) => !e.time.isBefore(start) && e.time.isBefore(end))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  void _prune() {
    final cutoff = clock.now().subtract(const Duration(days: _maxAgeDays));
    _events.removeWhere((e) => e.time.isBefore(cutoff));
  }

  void _load() {
    final raw = _storage.getString(AppConstants.keyBreakHistoryData);
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _events.addAll(
        decoded.map((e) => BreakEvent.fromJson(e as Map<String, dynamic>)),
      );
    } catch (e) {
      debugPrint('Error loading break history data: $e');
    }
  }

  void _persist() {
    _storage.setString(
      AppConstants.keyBreakHistoryData,
      jsonEncode(_events.map((e) => e.toJson()).toList()),
    );
  }
}
