import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/core/storage/models/daily_stats.dart';
import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/objectbox.g.dart';

class StorageService {
  late final Store store;
  late final Box<SettingsSnapshot> settingsBox;
  late final Box<DailyStats> dailyStatsBox;
  late final Box<GlobalStats> globalStatsBox;
  late final Box<CompanionPreferences> companionPreferencesBox;
  late final Box<KeyValueRecord> kvBox;

  int migrationDurationMs = 0;

  Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = p.join(docsDir.path, 'breakmate_db');

    store = await openStore(directory: storeDir);

    settingsBox = store.box<SettingsSnapshot>();
    dailyStatsBox = store.box<DailyStats>();
    globalStatsBox = store.box<GlobalStats>();
    companionPreferencesBox = store.box<CompanionPreferences>();
    kvBox = store.box<KeyValueRecord>();

    await _migrateFromSharedPreferences();
  }

  Future<int> getDatabaseSize() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final storeDir = p.join(docsDir.path, 'breakmate_db');
      final file = File(p.join(storeDir, 'data.mdb'));
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final isMigrated = prefs.getBool('objectbox_migrated') ?? false;
    if (isMigrated) return;

    final stopwatch = Stopwatch()..start();
    // Migrate all keys to KeyValueRecord as a fallback
    final keys = prefs.getKeys();
    for (final key in keys) {
      final value = prefs.get(key);
      if (value is int) {
        kvBox.put(
          KeyValueRecord(key: key, value: value.toString(), type: 'int'),
        );
      } else if (value is bool) {
        kvBox.put(
          KeyValueRecord(key: key, value: value.toString(), type: 'bool'),
        );
      } else if (value is double) {
        kvBox.put(
          KeyValueRecord(key: key, value: value.toString(), type: 'double'),
        );
      } else if (value is String) {
        kvBox.put(KeyValueRecord(key: key, value: value, type: 'string'));
      }
    }

    await prefs.setBool('objectbox_migrated', true);
    stopwatch.stop();
    migrationDurationMs = stopwatch.elapsedMilliseconds;
  }

  // --- KeyValue Compatibility Layer ---

  KeyValueRecord? _getKv(String key) {
    final query = kvBox.query(KeyValueRecord_.key.equals(key)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  Future<bool> setInt(String key, int value) async {
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value.toString();
      kvBox.put(existing);
    } else {
      kvBox.put(KeyValueRecord(key: key, value: value.toString(), type: 'int'));
    }
    return true;
  }

  int getInt(String key, {int defaultValue = 0}) {
    final kv = _getKv(key);
    if (kv != null && kv.type == 'int') {
      return int.tryParse(kv.value) ?? defaultValue;
    }
    return defaultValue;
  }

  Future<bool> setBool(String key, bool value) async {
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value.toString();
      kvBox.put(existing);
    } else {
      kvBox.put(
        KeyValueRecord(key: key, value: value.toString(), type: 'bool'),
      );
    }
    return true;
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final kv = _getKv(key);
    if (kv != null && kv.type == 'bool') {
      return kv.value == 'true';
    }
    return defaultValue;
  }

  Future<bool> setString(String key, String value) async {
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value;
      kvBox.put(existing);
    } else {
      kvBox.put(KeyValueRecord(key: key, value: value, type: 'string'));
    }
    return true;
  }

  String getString(String key, {String defaultValue = ''}) {
    final kv = _getKv(key);
    if (kv != null && kv.type == 'string') {
      return kv.value;
    }
    return defaultValue;
  }

  Future<bool> setDouble(String key, double value) async {
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value.toString();
      kvBox.put(existing);
    } else {
      kvBox.put(
        KeyValueRecord(key: key, value: value.toString(), type: 'double'),
      );
    }
    return true;
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    final kv = _getKv(key);
    if (kv != null && kv.type == 'double') {
      return double.tryParse(kv.value) ?? defaultValue;
    }
    return defaultValue;
  }
}
