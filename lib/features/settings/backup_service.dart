import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/core/storage/models/daily_stats.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/core/utils/file_permissions.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    show StatsService;
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/themes/application/theme_controller.dart';

/// What a backup file would restore, shown before anything is replaced.
class BackupPreview {
  const BackupPreview({
    required this.savedAt,
    required this.statDays,
    required this.breaksCompleted,
    required this.hasSettings,
  });

  final DateTime? savedAt;
  final int statDays;
  final int breaksCompleted;
  final bool hasSettings;
}

/// A backup checked against this installation, before anything is replaced.
class BackupPlan {
  const BackupPlan._({
    required this.settings,
    required this.records,
    required this.damagedKeys,
    required this.segments,
    required this.preferences,
    required this.issues,
  });

  final SettingsModel settings;

  // A null section is absent from the file and leaves current data alone.
  final List<KeyValueRecord>? records;
  final Set<String> damagedKeys;
  final List<ActivitySegment>? segments;
  final Map<String, Object>? preferences;

  /// Everything in the file that cannot be imported, in plain words.
  final List<String> issues;
}

class BackupService {
  BackupService(this._storage);

  final StorageService _storage;

  static const keyAutoBackup = 'auto_backup_enabled';
  static const keepLast = 7;

  // User choices kept only in SimplePrefs, outside the database.
  static const _preferenceKeys = [
    'daily_skip_limit',
    'skip_reasons_enabled',
    'skip_reason_log',
    'tod_profiles_enabled',
    'tod_morning',
    'tod_afternoon',
    'tod_evening',
  ];

  bool get autoEnabled => SimplePrefs.instance.getBool(keyAutoBackup);
  set autoEnabled(bool v) => SimplePrefs.instance.setBool(keyAutoBackup, v);

  /// The per-day rows StatsService maintains.
  List<Map<String, dynamic>> dailyStats() {
    final raw = _storage.getString(AppConstants.keyWeeklyStats);
    if (raw.isEmpty) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _activitySegments() {
    if (sl.isRegistered<ActivitySegmentRepository>()) {
      sl<ActivitySegmentRepository>().flush();
    }
    return _storage.activitySegmentBox
            ?.getAll()
            .map((e) => e.toMap())
            .toList() ??
        [];
  }

  Map<String, dynamic> build() => {
    'schemaVersion': AppConstants.backupSchemaVersion,
    'timestamp': DateTime.now().toIso8601String(),
    'settingsFormat': 'model',
    'settings': sl<SettingsRepository>().currentSettings.toMap(),
    'preferences': {
      for (final key in _preferenceKeys) key: ?SimplePrefs.instance.read(key),
    },
    'daily_stats': dailyStats(),
    'activity_segments': _activitySegments(),
    'kv_records':
        _storage.kvBox
            ?.getAll()
            .map((e) => {'key': e.key, 'value': e.value, 'type': e.type})
            .toList() ??
        [],
  };

  static Map<String, dynamic> parse(String content) {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      decoded = null;
    }
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('timestamp')) {
      throw AppException(
        type: AppErrorType.backup,
        message: "This file isn't a BreakMate backup, or it is damaged.",
      );
    }
    return decoded;
  }

  static BackupPreview preview(Map<String, dynamic> data) {
    final days = data['daily_stats'] is List
        ? (data['daily_stats'] as List).whereType<Map>().toList()
        : const <Map>[];
    return BackupPreview(
      savedAt: DateTime.tryParse('${data['timestamp']}'),
      statDays: days.length,
      breaksCompleted: days.fold(
        0,
        (sum, d) => sum + ((d['breaksCompleted'] as num?)?.toInt() ?? 0),
      ),
      hasSettings:
          data['settings'] is Map && (data['settings'] as Map).isNotEmpty,
    );
  }

  /// Works out what [data] can change here. Throws if it is unsafe to import.
  BackupPlan check(Map<String, dynamic> data) {
    final version = data['schemaVersion'];
    if (version is int && version > AppConstants.backupSchemaVersion) {
      throw AppException(
        type: AppErrorType.backup,
        message:
            'This backup was made by a newer version of BreakMate. '
            'Update the app, then import it.',
      );
    }

    T? section<T>(String name) {
      final value = data[name];
      if (value == null || value is T) return value as T?;
      throw AppException(
        type: AppErrorType.backup,
        message: 'The "$name" part of this file is damaged.',
      );
    }

    final issues = <String>[];

    final settings = _checkSettings(
      data['settingsFormat'] == 'model' ? section<Map>('settings') : null,
      issues,
    );

    List<KeyValueRecord>? records;
    final damagedKeys = <String>{};
    final rawRecords = section<List>('kv_records');
    if (rawRecords == null) {
      issues.add("Statistics aren't in this file. Yours stay as they are.");
    } else {
      records = [];
      var damaged = 0;
      for (final item in rawRecords) {
        final record = _record(item);
        if (record != null) {
          records.add(record);
          continue;
        }
        damaged++;
        if (item is Map && item['key'] is String) damagedKeys.add(item['key']);
      }
      if (damaged > 0) {
        issues.add('$damaged saved values are damaged and will be skipped.');
      }
    }

    List<ActivitySegment>? segments;
    final rawSegments = section<List>('activity_segments');
    if (rawSegments == null) {
      issues.add("Activity history isn't in this file. Yours stays as it is.");
    } else {
      segments = [];
      for (final item in rawSegments) {
        try {
          final segment = ActivitySegment.fromMap(
            Map<String, dynamic>.from(item),
          );
          if (segment.isValid && segment.date.isNotEmpty) {
            segments.add(segment);
          }
        } catch (_) {}
      }
      final skipped = rawSegments.length - segments.length;
      if (skipped > 0) {
        issues.add(
          '$skipped activity entries are damaged and will be skipped.',
        );
      }
    }

    Map<String, Object>? preferences;
    final rawPreferences = section<Map>('preferences');
    if (rawPreferences == null) {
      issues.add(
        "Skip limits and time-of-day profiles aren't in this file. "
        'Yours stay as they are.',
      );
    } else {
      preferences = {
        for (final key in _preferenceKeys)
          if (rawPreferences[key] case final Object value
              when value is String || value is int || value is bool)
            key: value,
      };
    }

    return BackupPlan._(
      settings: settings,
      records: records,
      damagedKeys: damagedKeys,
      segments: segments,
      preferences: preferences,
      issues: issues,
    );
  }

  // Applies the file's settings one at a time, so one bad value cannot block the rest.
  SettingsModel _checkSettings(Map? file, List<String> issues) {
    final current = sl<SettingsRepository>().currentSettings;
    if (file == null || file.isEmpty) {
      issues.add(
        'Settings are missing or in an old format. Yours stay as they are.',
      );
      return current;
    }

    final merged = current.toMap();
    final missing = merged.keys.where((k) => !file.containsKey(k)).toList();
    final unknown = <String>[];
    final invalid = <String>[];
    for (final entry in file.entries) {
      final key = '${entry.key}';
      final value = entry.value;
      if (!merged.containsKey(key)) {
        unknown.add(key);
        continue;
      }
      try {
        final parsed = SettingsModel.fromMap({
          ...merged,
          key: value,
        }).toMap()[key];
        final replaced =
            (value is String || value is num || value is bool) &&
            parsed != value;
        if (replaced) {
          invalid.add(key);
        } else {
          merged[key] = value;
        }
      } catch (_) {
        invalid.add(key);
      }
    }

    if (invalid.isNotEmpty) {
      issues.add(
        "These settings have values that can't be used, so yours stay: "
        '${_names(invalid)}.',
      );
    }
    if (unknown.isNotEmpty) {
      issues.add(
        "This version doesn't support these settings: ${_names(unknown)}.",
      );
    }
    if (missing.isNotEmpty) {
      issues.add(
        "These settings aren't in the file, so yours stay: ${_names(missing)}.",
      );
    }

    final settings = SettingsModel.fromMap(merged);
    final image = settings.customImagePath;
    if (image != null && image.isNotEmpty && !File(image).existsSync()) {
      issues.add("The custom background image isn't on this computer: $image");
    }
    return settings;
  }

  static String _names(List<String> keys) {
    final words = [
      for (final key in keys.take(6))
        key.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}'),
      if (keys.length > 6) '${keys.length - 6} more',
    ];
    return words.join(', ');
  }

  static KeyValueRecord? _record(Object? item) {
    if (item is! Map) return null;
    final key = item['key'];
    final value = item['value'];
    final type = item['type'];
    if (key is! String || value is! String) return null;
    final readable = switch (type) {
      'string' => true,
      'bool' => value == 'true' || value == 'false',
      'int' => int.tryParse(value) != null,
      'double' => double.tryParse(value) != null,
      _ => false,
    };
    return readable
        ? KeyValueRecord(key: key, value: value, type: type as String)
        : null;
  }

  /// Replaces current data with the backup and returns what could not be
  /// imported. If writing fails, the previous data is put back.
  Future<List<String>> restore(Map<String, dynamic> data) async {
    final plan = check(data);
    final previous = check(build());
    try {
      await _apply(plan);
    } catch (e, st) {
      ErrorHandler().handleError(e, st, type: AppErrorType.backup);
      var outcome = 'Your previous data is unchanged.';
      try {
        await _apply(previous);
      } catch (e, st) {
        ErrorHandler().handleError(e, st, type: AppErrorType.backup);
        outcome = 'Your previous data could not be fully put back.';
      }
      await _reloadServices();
      throw AppException(
        type: AppErrorType.backup,
        message: "The backup couldn't be saved. $outcome",
        originalError: e,
      );
    }

    final repository = sl<SettingsRepository>();
    await repository.load();
    final wanted = plan.settings.toMap();
    final saved = repository.currentSettings.toMap();
    final mismatched = [
      for (final key in wanted.keys)
        if (jsonEncode(wanted[key]) != jsonEncode(saved[key])) key,
    ];
    await _reloadServices();
    return [
      ...plan.issues,
      if (mismatched.isNotEmpty)
        "These settings couldn't be updated: ${_names(mismatched)}.",
    ];
  }

  Future<void> _apply(BackupPlan plan) async {
    final prefs = SimplePrefs.instance;

    final records = plan.records;
    if (records != null) {
      final current = _storage.kvBox?.getAll() ?? <KeyValueRecord>[];
      final incoming = {for (final r in records) r.key};
      final kept = [
        for (final r in current)
          if (plan.damagedKeys.contains(r.key) && !incoming.contains(r.key))
            KeyValueRecord(key: r.key, value: r.value, type: r.type),
      ];
      // Reads fall back to SimplePrefs, so replaced keys must leave it too.
      for (final r in current) {
        if (!incoming.contains(r.key) && !plan.damagedKeys.contains(r.key)) {
          prefs.remove(r.key);
        }
      }
      _storage.kvBox?.removeAll();
      for (final r in [...records, ...kept]) {
        _storage.kvBox?.put(
          KeyValueRecord(key: r.key, value: r.value, type: r.type),
        );
        switch (r.type) {
          case 'int':
            prefs.setInt(r.key, int.parse(r.value));
          case 'bool':
            prefs.setBool(r.key, r.value == 'true');
          case 'double':
            prefs.setDouble(r.key, double.parse(r.value));
          default:
            prefs.setString(r.key, r.value);
        }
      }
    }

    final preferences = plan.preferences;
    if (preferences != null) {
      for (final key in _preferenceKeys) {
        switch (preferences[key]) {
          case final String value:
            prefs.setString(key, value);
          case final int value:
            prefs.setInt(key, value);
          case final bool value:
            prefs.setBool(key, value);
          default:
            prefs.remove(key);
        }
      }
    }

    final segments = plan.segments;
    if (segments != null) {
      if (sl.isRegistered<ActivitySegmentRepository>()) {
        sl<ActivitySegmentRepository>().clearAll();
      }
      _storage.activitySegmentBox?.removeAll();
      _storage.activitySegmentBox?.putMany([
        for (final s in segments) ActivitySegment.fromMap(s.toMap()),
      ]);
    }

    // Last, so the imported settings win over any older copy among the records.
    await sl<SettingsRepository>().save(plan.settings);
  }

  /// Daily stats rows from a CSV or TSV export, with the line numbers that
  /// could not be read.
  static ({List<DailyStats> rows, List<int> skipped}) parseStatsTable(
    String content,
  ) {
    final lines = content.replaceFirst('\uFEFF', '').split(RegExp(r'\r?\n'));
    String clean(String v) => v.trim().replaceAll('"', '');
    // Tolerates spreadsheet re-saves that switch the delimiter.
    final delimiter = lines.first.contains('\t')
        ? '\t'
        : lines.first.contains(';') && !lines.first.contains(',')
        ? ';'
        : ',';
    final columns = [
      for (final h in lines.first.split(delimiter)) clean(h).toLowerCase(),
    ];
    const required = [
      'date',
      'breakscompleted',
      'breaksskipped',
      'usageminutes',
    ];
    if (!required.every(columns.contains)) {
      throw AppException(
        type: AppErrorType.backup,
        message:
            "This isn't a daily stats file. It needs the columns Date, "
            'BreaksCompleted, BreaksSkipped and UsageMinutes.',
      );
    }

    final rows = <DailyStats>[];
    final skipped = <int>[];
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final parts = lines[i].split(delimiter).map(clean).toList();
      String at(String column) {
        final index = columns.indexOf(column);
        return index >= 0 && index < parts.length ? parts[index] : '';
      }

      final date = at('date');
      final done = int.tryParse(at('breakscompleted'));
      final missed = int.tryParse(at('breaksskipped'));
      final usage = int.tryParse(at('usageminutes'));
      final wellness = columns.contains('wellnessactions')
          ? int.tryParse(at('wellnessactions'))
          : 0;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          done == null ||
          missed == null ||
          usage == null ||
          wellness == null) {
        skipped.add(i + 1);
        continue;
      }
      rows.add(
        DailyStats(
          date: date,
          breaksCompleted: done,
          breaksSkipped: missed,
          usageMinutes: usage,
          wellnessActions: wellness,
        ),
      );
    }
    if (rows.isEmpty) {
      throw AppException(
        type: AppErrorType.backup,
        message: 'No daily stats could be read from this file.',
      );
    }
    return (rows: rows, skipped: skipped);
  }

  // These cache their data in memory and would overwrite the restored copy.
  Future<void> _reloadServices() async {
    if (sl.isRegistered<AppUsageService>()) sl<AppUsageService>().reload();
    if (sl.isRegistered<FocusSessionService>()) {
      sl<FocusSessionService>().reload();
    }
    if (sl.isRegistered<BreakHistoryService>()) {
      sl<BreakHistoryService>().reload();
    }
    if (sl.isRegistered<AdaptiveBreakService>()) {
      sl<AdaptiveBreakService>().reload();
    }
    if (sl.isRegistered<ThemeController>()) sl<ThemeController>().reload();
    if (sl.isRegistered<ProductivityRepository>()) {
      sl<ProductivityRepository>().invalidate();
    }
    if (sl.isRegistered<StatsService>()) {
      await sl<StatsService>().initialize();
    }
  }

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'backups')).create(recursive: true);
  }

  /// Local backups, newest first.
  Future<List<File>> list() async {
    final files = (await _dir()).listSync().whereType<File>().where(
      (f) => p.basename(f.path).startsWith('breakmate_auto_'),
    );
    return files.toList()..sort((a, b) => b.path.compareTo(a.path));
  }

  /// Writes today's backup once, then drops all but the newest [keepLast].
  Future<File?> runIfDue() async {
    if (!autoEnabled) return null;
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = 'breakmate_auto_${n.year}-${two(n.month)}-${two(n.day)}.json';
    final file = File(p.join((await _dir()).path, name));
    if (file.existsSync()) return null;
    await file.writeAsString(jsonEncode(build()));
    await restrictToOwner(file.path);
    for (final old in (await list()).skip(keepLast)) {
      await old.delete();
    }
    return file;
  }
}
