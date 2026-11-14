import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/storage/models/daily_stats.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/core/utils/file_permissions.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

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

class BackupService {
  BackupService(this._storage);

  final StorageService _storage;

  static const keyAutoBackup = 'auto_backup_enabled';
  static const keepLast = 7;

  bool get autoEnabled => SimplePrefs.instance.getBool(keyAutoBackup);
  set autoEnabled(bool v) => SimplePrefs.instance.setBool(keyAutoBackup, v);

  Map<String, dynamic> build() => {
    'schemaVersion': AppConstants.backupSchemaVersion,
    'timestamp': DateTime.now().toIso8601String(),
    'settingsFormat': 'model',
    'settings': sl<SettingsRepository>().currentSettings.toMap(),
    'companion': _storage.companionPreferencesBox?.get(1)?.toMap() ?? {},
    'global_stats': _storage.globalStatsBox?.get(1)?.toMap() ?? {},
    'daily_stats':
        _storage.dailyStatsBox?.getAll().map((e) => e.toMap()).toList() ?? [],
    'kv_records':
        _storage.kvBox
            ?.getAll()
            .map((e) => {'key': e.key, 'value': e.value, 'type': e.type})
            .toList() ??
        [],
  };

  static Map<String, dynamic> parse(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('timestamp')) {
      throw AppException(
        type: AppErrorType.backup,
        message: 'Invalid backup file format',
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

  Future<void> restore(Map<String, dynamic> data) async {
    if (data['settingsFormat'] == 'model' &&
        data['settings'] is Map &&
        (data['settings'] as Map).isNotEmpty) {
      await sl<SettingsRepository>().save(
        SettingsModel.fromMap(Map<String, dynamic>.from(data['settings'])),
      );
    }

    if (data['global_stats'] is Map &&
        (data['global_stats'] as Map).isNotEmpty) {
      final g = Map<String, dynamic>.from(data['global_stats']);
      _storage.globalStatsBox?.put(
        GlobalStats(
          id: 1,
          currentStreak: g['currentStreak'] ?? 0,
          longestStreak: g['longestStreak'] ?? 0,
          totalWorkSessions: g['totalWorkSessions'] ?? 0,
          lastActiveDate: g['lastActiveDate'] ?? '',
        ),
      );
    }

    if (data['daily_stats'] is List) {
      _storage.dailyStatsBox?.removeAll();
      for (final item in (data['daily_stats'] as List).whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        _storage.dailyStatsBox?.put(
          DailyStats(
            id: 0,
            date: m['date'] ?? '',
            breaksCompleted: m['breaksCompleted'] ?? 0,
            breaksSkipped: m['breaksSkipped'] ?? 0,
            usageMinutes: m['usageMinutes'] ?? 0,
            wellnessActions: m['wellnessActions'] ?? 0,
          ),
        );
      }
    }

    if (data['kv_records'] is List) {
      _storage.kvBox?.removeAll();
      final prefs = SimplePrefs.instance;
      for (final item in (data['kv_records'] as List).whereType<Map>()) {
        final key = item['key'] as String?;
        final value = item['value'] as String?;
        final type = item['type'] as String?;
        if (key == null || value == null || type == null) continue;
        _storage.kvBox?.put(KeyValueRecord(key: key, value: value, type: type));
        switch (type) {
          case 'int':
            final v = int.tryParse(value);
            if (v != null) prefs.setInt(key, v);
          case 'bool':
            prefs.setBool(key, value == 'true');
          case 'string':
            prefs.setString(key, value);
          case 'double':
            final v = double.tryParse(value);
            if (v != null) prefs.setDouble(key, v);
        }
      }
    }

    await sl<SettingsRepository>().load();
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
