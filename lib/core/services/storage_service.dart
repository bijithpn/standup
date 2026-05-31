import 'dart:isolate';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
    final isSecondaryIsolate = isolateName.toLowerCase().contains('overlay') ||
        isolateName.toLowerCase().contains('companion');
    
    debugPrint('[Storage] Initializing in isolate: "$isolateName" (isSecondaryIsolate: $isSecondaryIsolate)');
    
    if (isSecondaryIsolate) {
       debugPrint('[Storage] Bypassing initialization in secondary isolate: $isolateName');
       return;
    }

    _initializing = true;
    _failed = false;
    try {
      final supportDir = await getApplicationSupportDirectory();
      final docsDir = await getApplicationDocumentsDirectory();
      
      debugPrint('[Storage] Support Dir: ${supportDir.path}');
      debugPrint('[Storage] Docs Dir: ${docsDir.path}');
      
      // New primary location
      final storeDir = p.join(supportDir.path, 'breakmate_db');
      // Old location (legacy)
      final legacyStoreDir = p.join(docsDir.path, 'breakmate_db');

      // Simple migration: if legacy exists and new doesn't, move it.
      if (Directory(legacyStoreDir).existsSync() && !Directory(storeDir).existsSync()) {
        debugPrint('[Storage] Migrating database from legacy location: $legacyStoreDir to $storeDir');
        try {
          Directory(storeDir).parent.createSync(recursive: true);
          Directory(legacyStoreDir).renameSync(storeDir);
          debugPrint('[Storage] Migration successful.');
        } catch (e) {
          debugPrint('[Storage] Migration failed: $e. Staying with existing paths.');
        }
      }

      final activeStoreDir = Directory(storeDir).existsSync() ? storeDir : 
                             (Directory(legacyStoreDir).existsSync() ? legacyStoreDir : storeDir);

      await diagnoseStorage(activeStoreDir);

      // Ensure the directory exists
      final dir = Directory(activeStoreDir);
      if (!dir.existsSync()) {
        debugPrint('[Storage] Creating store directory: $activeStoreDir');
        dir.createSync(recursive: true);
      }

      debugPrint('[Storage] Opening ObjectBox store at $activeStoreDir...');
      try {
        _store = await openStore(directory: activeStoreDir);
        debugPrint('[Storage] Store opened successfully.');
      } catch (e) {
        debugPrint('[Storage] Failed to open store: $e');
        
        // Attempt cleanup if it looks like a locking issue
        if (e.toString().contains('Operation not permitted') || e.toString().contains('Lock')) {
          debugPrint('[Storage] Attempting to clean up stale lock files...');
          try {
            final lockFile = File(p.join(activeStoreDir, 'lock.mdb'));
            if (lockFile.existsSync()) {
              lockFile.deleteSync();
              debugPrint('[Storage] Deleted stale lock.mdb');
            }
            _store = await openStore(directory: activeStoreDir);
            debugPrint('[Storage] Store opened after cleanup.');
          } catch (retryError) {
            debugPrint('[Storage] Cleanup retry failed: $retryError');
          }
        }

        if (_store == null) {
          // Fallback: try Documents directory if Support failed (for some reason)
          if (activeStoreDir != legacyStoreDir) {
             debugPrint('[Storage] Attempting fallback to legacy location $legacyStoreDir...');
             try {
                Directory(legacyStoreDir).createSync(recursive: true);
                _store = await openStore(directory: legacyStoreDir);
             } catch (_) {}
          }
          
          if (_store == null) {
            // Last resort: temporary directory (will lose data on OS cleanup)
            try {
              final tempDir = await getTemporaryDirectory();
              final fallbackPath = p.join(tempDir.path, 'breakmate_fallback');
              debugPrint('[Storage] WARNING: Falling back to temporary storage at $fallbackPath. Data will not persist reliably.');
              Directory(fallbackPath).createSync(recursive: true);
              _store = await openStore(directory: fallbackPath);
              debugPrint('[Storage] Fallback store opened successfully.');
            } catch (fallbackError) {
              debugPrint('[Storage] FATAL: All storage options failed: $fallbackError');
              _failed = true;
              return;
            }
          }
        }
      }

      if (_store != null) {
        settingsBox = _store!.box<SettingsSnapshot>();
        dailyStatsBox = _store!.box<DailyStats>();
        globalStatsBox = _store!.box<GlobalStats>();
        companionPreferencesBox = _store!.box<CompanionPreferences>();
        kvBox = _store!.box<KeyValueRecord>();
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
      final docsDir = await getApplicationDocumentsDirectory();
      final storeDir = p.join(docsDir.path, 'breakmate_db');
      final file = File(p.join(storeDir, 'data.mdb'));
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
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
