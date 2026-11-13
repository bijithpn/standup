import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';

/// Persisted focus sessions grouped by date (30-day retention); written by AppUsageTracker, read by scores, streaks and insights.
class FocusSessionService extends ChangeNotifier {
  final StorageService _storage;
  final Map<String, List<FocusSession>> _cache = {};

  FocusSessionService({required StorageService storage}) : _storage = storage {
    _load();
  }

  void recordSession(FocusSession session) {
    final date = _dateKey(session.start);
    _cache.putIfAbsent(date, () => []).add(session);
    _pruneOldDates();
    _persist();
    notifyListeners();
  }

  void clear() {
    _cache.clear();
    _persist();
    notifyListeners();
  }

  List<FocusSession> sessionsForDate(String date) =>
      List.unmodifiable(_cache[date] ?? const []);

  int focusSecondsForDate(String date) =>
      (_cache[date] ?? const []).fold(0, (sum, s) => sum + s.durationSeconds);

  /// Focus score = focus seconds / total active seconds for the day, 0..1.
  double focusScore(String date, {required int totalActiveSeconds}) {
    if (totalActiveSeconds <= 0) return 0.0;
    return (focusSecondsForDate(date) / totalActiveSeconds).clamp(0.0, 1.0);
  }

  List<FocusSession> sessionsForPeriod(UsagePeriod period, {DateTime? now}) {
    final today = now ?? clock.now();
    final result = <FocusSession>[];
    for (final dateEntry in _cache.entries) {
      if (!_dateInPeriod(dateEntry.key, period, today)) continue;
      result.addAll(dateEntry.value);
    }
    result.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    return result;
  }

  int focusSecondsForPeriod(UsagePeriod period, {DateTime? now}) {
    return sessionsForPeriod(
      period,
      now: now,
    ).fold(0, (sum, s) => sum + s.durationSeconds);
  }

  bool _dateInPeriod(String date, UsagePeriod period, DateTime now) {
    final parsed = _parseDateKey(date);
    if (parsed == null) return false;

    switch (period) {
      case UsagePeriod.today:
        return parsed.year == now.year &&
            parsed.month == now.month &&
            parsed.day == now.day;
      case UsagePeriod.week:
        final diff = DateTime(
          now.year,
          now.month,
          now.day,
        ).difference(parsed).inDays;
        return diff >= 0 && diff < 7;
      case UsagePeriod.month:
        return parsed.year == now.year && parsed.month == now.month;
    }
  }

  List<FocusSession> sessionsBetween(DateTime start, DateTime end) {
    final result = <FocusSession>[];
    for (final list in _cache.values) {
      for (final session in list) {
        if (!session.start.isBefore(start) && session.start.isBefore(end)) {
          result.add(session);
        }
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  void _pruneOldDates() {
    final cutoff = clock.now().subtract(const Duration(days: 30));
    _cache.removeWhere((date, _) {
      final parsed = _parseDateKey(date);
      return parsed == null || parsed.isBefore(cutoff);
    });
  }

  void _load() {
    final raw = _storage.getString(AppConstants.keyFocusSessionData);
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final dateEntry in decoded.entries) {
        final sessions = (dateEntry.value as List<dynamic>)
            .map((e) => FocusSession.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache[dateEntry.key] = sessions;
      }
    } catch (e) {
      debugPrint('Error loading focus session data: $e');
    }
  }

  void _persist() {
    final jsonMap = <String, dynamic>{
      for (final entry in _cache.entries)
        entry.key: entry.value.map((s) => s.toJson()).toList(),
    };
    _storage.setString(AppConstants.keyFocusSessionData, jsonEncode(jsonMap));
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  DateTime? _parseDateKey(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
