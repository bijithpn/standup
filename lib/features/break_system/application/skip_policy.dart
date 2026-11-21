import 'dart:convert';

import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/settings/break_profile.dart';

/// User-configurable limits on skipping breaks, plus the log of why breaks were skipped.
class SkipPolicy {
  static const _limitKey = 'daily_skip_limit';
  static const _reasonsKey = 'skip_reasons_enabled';
  static const _logKey = 'skip_reason_log';
  static const _maxLogEntries = 200;

  static const maxSnoozesPerDay = 3;
  static const snoozeMinutes = 5;
  static const _snoozeDayKey = 'snooze_day';
  static const _snoozeCountKey = 'snooze_count';

  static const reasons = ['In a meeting', 'Deep focus', 'Not needed', 'Other'];

  static int get dailyLimit => SimplePrefs.instance.getInt(_limitKey);
  static set dailyLimit(int v) => SimplePrefs.instance.setInt(_limitKey, v);

  static bool get reasonsEnabled => SimplePrefs.instance.getBool(_reasonsKey);
  static set reasonsEnabled(bool v) =>
      SimplePrefs.instance.setBool(_reasonsKey, v);

  static int skipsToday(List<BreakEvent> events, DateTime now) => events
      .where(
        (e) =>
            !e.completed &&
            e.time.year == now.year &&
            e.time.month == now.month &&
            e.time.day == now.day,
      )
      .length;

  static bool isLocked(List<BreakEvent> events, DateTime now) =>
      dailyLimit > 0 && skipsToday(events, now) >= dailyLimit;

  static String _day(DateTime t) => '${t.year}-${t.month}-${t.day}';

  static int snoozesToday(DateTime now) =>
      SimplePrefs.instance.getString(_snoozeDayKey) == _day(now)
      ? SimplePrefs.instance.getInt(_snoozeCountKey)
      : 0;

  static bool isSnoozeLocked(DateTime now) =>
      snoozesToday(now) >= maxSnoozesPerDay;

  static void recordSnooze(DateTime now) {
    final count = snoozesToday(now) + 1;
    SimplePrefs.instance.setString(_snoozeDayKey, _day(now));
    SimplePrefs.instance.setInt(_snoozeCountKey, count);
  }

  static void recordReason(String reason, DateTime now) {
    final log = _readLog()
      ..add({'time': now.toIso8601String(), 'reason': reason});
    final kept = log.length > _maxLogEntries
        ? log.sublist(log.length - _maxLogEntries)
        : log;
    SimplePrefs.instance.setString(_logKey, jsonEncode(kept));
  }

  static Map<String, int> reasonCounts() {
    final counts = <String, int>{};
    for (final e in _readLog()) {
      final r = e['reason'] as String? ?? 'Other';
      counts[r] = (counts[r] ?? 0) + 1;
    }
    return counts;
  }

  static List<Map<String, dynamic>> _readLog() {
    try {
      final raw = SimplePrefs.instance.getString(_logKey);
      if (raw.isEmpty) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}

enum DayPart { morning, afternoon, evening }

/// Optional break profile per part of the day; an empty id means "use the base profile".
class TimeOfDayProfiles {
  static const _enabledKey = 'tod_profiles_enabled';

  static bool get enabled => SimplePrefs.instance.getBool(_enabledKey);
  static set enabled(bool v) => SimplePrefs.instance.setBool(_enabledKey, v);

  static DayPart periodAt(DateTime t) => t.hour >= 5 && t.hour < 12
      ? DayPart.morning
      : t.hour >= 12 && t.hour < 17
      ? DayPart.afternoon
      : DayPart.evening;

  static String profileId(DayPart p) =>
      SimplePrefs.instance.getString('tod_${p.name}');

  static void setProfileId(DayPart p, String id) =>
      SimplePrefs.instance.setString('tod_${p.name}', id);

  static BreakProfile? activeAt(DateTime t) {
    if (!enabled) return null;
    final id = profileId(periodAt(t));
    for (final p in BreakProfile.presets) {
      if (p.id == id) return p;
    }
    return null;
  }
}
