import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

class _AppUsageRecord {
  final String name;
  final AppCategory category;
  final int seconds;

  const _AppUsageRecord({
    required this.name,
    required this.category,
    required this.seconds,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category.name,
    'seconds': seconds,
  };

  factory _AppUsageRecord.fromJson(Map<String, dynamic> json) {
    return _AppUsageRecord(
      name: json['name'] as String? ?? 'Unknown',
      category: AppCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => AppCategory.general,
      ),
      seconds: (json['seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Local, opt-in per-app usage history: a JSON blob in [StorageService],
/// keyed by date then app identifier, pruned to a 30-day rolling window.
class AppUsageService extends ChangeNotifier {
  final StorageService _storage;
  final Map<String, Map<String, _AppUsageRecord>> _cache = {};

  AppUsageService({required StorageService storage}) : _storage = storage {
    _load();
  }

  void addUsageSeconds({
    required String date,
    required String appKey,
    required String name,
    required AppCategory category,
    required int seconds,
  }) {
    final dayMap = _cache.putIfAbsent(date, () => {});
    final existingSeconds = dayMap[appKey]?.seconds ?? 0;
    dayMap[appKey] = _AppUsageRecord(
      name: name,
      category: category,
      seconds: existingSeconds + seconds,
    );

    _pruneOldDates();
    _persist();
    notifyListeners();
  }

  /// Returns usage entries for [period], sorted by time spent descending.
  /// Pass `limit: null` to return every tracked app instead of a cut-off
  /// top N — used by the Privacy dashboard, which promises to show
  /// everything that's been recorded, not just the highlights.
  List<AppUsageEntry> topApps(
    UsagePeriod period, {
    int? limit = 8,
    DateTime? now,
  }) {
    final today = now ?? clock.now();
    final totals = <String, int>{};
    final names = <String, String>{};
    final categories = <String, AppCategory>{};

    for (final dateEntry in _cache.entries) {
      if (!_dateInPeriod(dateEntry.key, period, today)) continue;
      for (final appEntry in dateEntry.value.entries) {
        final record = appEntry.value;
        totals[appEntry.key] = (totals[appEntry.key] ?? 0) + record.seconds;
        names[appEntry.key] = record.name;
        categories[appEntry.key] = record.category;
      }
    }

    final entries = totals.entries
        .map(
          (e) => AppUsageEntry(
            appKey: e.key,
            name: names[e.key] ?? e.key,
            category: categories[e.key] ?? AppCategory.general,
            seconds: e.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));

    return limit == null ? entries : entries.take(limit).toList();
  }

  Map<AppCategory, int> categoryTotals(UsagePeriod period, {DateTime? now}) {
    final today = now ?? clock.now();
    final totals = <AppCategory, int>{
      for (final c in AppCategory.values) c: 0,
    };

    for (final dateEntry in _cache.entries) {
      if (!_dateInPeriod(dateEntry.key, period, today)) continue;
      for (final record in dateEntry.value.values) {
        totals[record.category] = (totals[record.category] ?? 0) + record.seconds;
      }
    }

    return totals;
  }

  bool _dateInPeriod(String date, UsagePeriod period, DateTime now) {
    final parts = date.split('-');
    if (parts.length != 3) return false;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return false;
    final dt = DateTime(y, m, d);

    switch (period) {
      case UsagePeriod.today:
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      case UsagePeriod.week:
        final diff = DateTime(now.year, now.month, now.day).difference(dt).inDays;
        return diff >= 0 && diff < 7;
      case UsagePeriod.month:
        return dt.year == now.year && dt.month == now.month;
    }
  }

  void _pruneOldDates() {
    final cutoff = clock.now().subtract(const Duration(days: 30));
    _cache.removeWhere((date, _) {
      final parts = date.split('-');
      if (parts.length != 3) return true;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) return true;
      return DateTime(y, m, d).isBefore(cutoff);
    });
  }

  void _load() {
    final raw = _storage.getString(AppConstants.keyAppUsageData);
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final dateEntry in decoded.entries) {
        final dayMap = <String, _AppUsageRecord>{};
        final appsJson = dateEntry.value as Map<String, dynamic>;
        for (final appEntry in appsJson.entries) {
          dayMap[appEntry.key] =
              _AppUsageRecord.fromJson(appEntry.value as Map<String, dynamic>);
        }
        _cache[dateEntry.key] = dayMap;
      }
    } catch (e) {
      debugPrint('Error loading app usage data: $e');
    }
  }

  void _persist() {
    final jsonMap = <String, dynamic>{
      for (final dateEntry in _cache.entries)
        dateEntry.key: {
          for (final appEntry in dateEntry.value.entries)
            appEntry.key: appEntry.value.toJson(),
        },
    };
    _storage.setString(AppConstants.keyAppUsageData, jsonEncode(jsonMap));
  }
}
