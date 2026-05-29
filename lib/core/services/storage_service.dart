import 'dart:isolate';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/core/storage/models/daily_stats.dart';
import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/objectbox.g.dart';

class StorageService {
  static Store? _store;
  static bool _initializing = false;
  static bool _failed = false;

  bool get isReady => _store != null;
  bool get hasFailed => _failed;

  Store get store {
    if (_store == null) {
      throw StateError('StorageService not initialized. Call init() first and wait for completion.');
    }
    return _store!;
  }

  Box<SettingsSnapshot>? settingsBox;
  Box<DailyStats>? dailyStatsBox;
  Box<GlobalStats>? globalStatsBox;
  Box<CompanionPreferences>? companionPreferencesBox;
  Box<KeyValueRecord>? kvBox;

  int migrationDurationMs = 0;

  Future<void> init() async {
    if (_store != null) return;
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    final isolateName = Isolate.current.debugName ?? '';
    final isMain = isolateName == 'main' || isolateName == 'root' || isolateName.isEmpty;
    
    debugPrint('[Storage] Initializing in isolate: "$isolateName" (isMain: $isMain)');
    
    if (!isMain && !isolateName.contains('StatsWorker')) {
       debugPrint('[Storage] Bypassing initialization in secondary isolate: $isolateName');
       return;
    }

    _initializing = true;
    _failed = false;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      
      // Prefer Documents inside sandbox container if Application Support fails
      // In macOS Sandbox, both are mapped to private container folders.
      final storeDir = p.join(docsDir.path, 'breakmate_db');

      await diagnoseStorage(storeDir);

      // Ensure the directory exists
      final dir = Directory(storeDir);
      if (!dir.existsSync()) {
        debugPrint('[Storage] Creating store directory: $storeDir');
        dir.createSync(recursive: true);
      }

      debugPrint('[Storage] Opening ObjectBox store at $storeDir...');
      try {
        _store = await openStore(directory: storeDir);
        debugPrint('[Storage] Store opened successfully.');
      } catch (e) {
        debugPrint('[Storage] Failed to open store: $e');
        
        // Attempt cleanup if it looks like a locking issue
        if (e.toString().contains('Operation not permitted')) {
          debugPrint('[Storage] Attempting to clean up stale lock files...');
          try {
            final lockFile = File(p.join(storeDir, 'lock.mdb'));
            if (lockFile.existsSync()) {
              lockFile.deleteSync();
              debugPrint('[Storage] Deleted stale lock.mdb');
            }
            _store = await openStore(directory: storeDir);
            debugPrint('[Storage] Store opened after cleanup.');
          } catch (retryError) {
            debugPrint('[Storage] Cleanup retry failed: $retryError');
          }
        }

        if (_store == null) {
          // Fallback: try temporary directory
          try {
            final tempDir = await getTemporaryDirectory();
            final fallbackPath = p.join(tempDir.path, 'breakmate_fallback');
            debugPrint('[Storage] Attempting fallback to $fallbackPath...');
            Directory(fallbackPath).createSync(recursive: true);
            _store = await openStore(directory: fallbackPath);
            debugPrint('[Storage] Fallback store opened successfully.');
          } catch (fallbackError) {
            debugPrint('[Storage] FATAL: Fallback also failed: $fallbackError');
            _failed = true;
            return;
          }
        }
      }

      if (_store != null) {
        settingsBox = _store!.box<SettingsSnapshot>();
        dailyStatsBox = _store!.box<DailyStats>();
        globalStatsBox = _store!.box<GlobalStats>();
        companionPreferencesBox = _store!.box<CompanionPreferences>();
        kvBox = _store!.box<KeyValueRecord>();

        await _migrateFromSharedPreferences();
      } else {
        _failed = true;
      }
    } catch (e) {
      debugPrint('[Storage] Unexpected error during init: $e');
      _failed = true;
    } finally {
      _initializing = false;
    }
  }

  Future<void> diagnoseStorage(String storeDir) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      
      debugPrint('--- STORAGE DIAGNOSTICS ---');
      debugPrint('App Docs Dir: ${docsDir.path}');
      debugPrint('Store Dir: $storeDir');
      debugPrint('Home: ${Platform.environment['HOME']}');
      
      final dir = Directory(storeDir);
      debugPrint('Dir exists: ${dir.existsSync()}');
      
      // Test write permission
      final testFile = File(p.join(docsDir.path, '.write_test'));
      testFile.writeAsStringSync('test');
      debugPrint('Write test: SUCCESS');
      testFile.deleteSync();
      debugPrint('Delete test: SUCCESS');
      
      debugPrint('---------------------------');
    } catch (e) {
      debugPrint('--- STORAGE DIAGNOSTICS FAILURE ---');
      debugPrint('Error: $e');
      debugPrint('---------------------------');
    }
  }

  Future<int> getDatabaseSize() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final storeDir = p.join(supportDir.path, 'breakmate_v1');
      final file = File(p.join(storeDir, 'data.mdb'));
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _migrateFromSharedPreferences() async {
    if (kvBox == null) return;
    final prefs = await SharedPreferences.getInstance();
    final isMigrated = prefs.getBool('objectbox_migrated') ?? false;
    if (isMigrated) return;

    final stopwatch = Stopwatch()..start();
    // Migrate all keys to KeyValueRecord as a fallback
    final keys = prefs.getKeys();
    for (final key in keys) {
      final value = prefs.get(key);
      if (value is int) {
        kvBox?.put(
          KeyValueRecord(key: key, value: value.toString(), type: 'int'),
        );
      } else if (value is bool) {
        kvBox?.put(
          KeyValueRecord(key: key, value: value.toString(), type: 'bool'),
        );
      } else if (value is double) {
        kvBox?.put(
          KeyValueRecord(key: key, value: value.toString(), type: 'double'),
        );
      } else if (value is String) {
        kvBox?.put(KeyValueRecord(key: key, value: value, type: 'string'));
      }
    }

    await prefs.setBool('objectbox_migrated', true);
    stopwatch.stop();
    migrationDurationMs = stopwatch.elapsedMilliseconds;
  }

  // --- KeyValue Compatibility Layer ---

  KeyValueRecord? _getKv(String key) {
    if (kvBox == null) return null;
    final query = kvBox!.query(KeyValueRecord_.key.equals(key)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  Future<bool> setInt(String key, int value) async {
    if (kvBox == null) return false;
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value.toString();
      kvBox!.put(existing);
    } else {
      kvBox!.put(KeyValueRecord(key: key, value: value.toString(), type: 'int'));
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
    if (kvBox == null) return false;
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value.toString();
      kvBox!.put(existing);
    } else {
      kvBox!.put(
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
    if (kvBox == null) return false;
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value;
      kvBox!.put(existing);
    } else {
      kvBox!.put(KeyValueRecord(key: key, value: value, type: 'string'));
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
    if (kvBox == null) return false;
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value.toString();
      kvBox!.put(existing);
    } else {
      kvBox!.put(
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
