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
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:package_info_plus/package_info_plus.dart';

class StorageService {
  static Store? _store;
  static bool _initializing = false;
  static bool _failed = false;

  bool get isReady => _store != null;
  bool get hasFailed => _failed;

  String? activeDatabasePath;
  int? openDurationMs;
  int? initDurationMs;

  Store get store {
    final isolateName = Isolate.current.debugName ?? '';
    final isSecondaryIsolate =
        isolateName.toLowerCase().contains('overlay') ||
        isolateName.toLowerCase().contains('companion');
    if (isSecondaryIsolate) {
      debugPrint(
        '[Storage] 🚨 REJECTED: Secondary isolate "$isolateName" attempted to access ObjectBox store! Rejecting access to prevent corruption.',
      );
      throw StateError('Storage access rejected in secondary isolates.');
    }
    if (_store == null) {
      throw StateError(
        'StorageService not initialized. Call init() first and wait for completion.',
      );
    }
    return _store!;
  }

  Box<SettingsSnapshot>? settingsBox;
  Box<DailyStats>? dailyStatsBox;
  Box<GlobalStats>? globalStatsBox;
  Box<CompanionPreferences>? companionPreferencesBox;
  Box<KeyValueRecord>? kvBox;

  int get migrationDurationMs =>
      SimplePrefs.instance.getInt('database_migration_ms', defaultValue: 0);
  set migrationDurationMs(int val) =>
      SimplePrefs.instance.setInt('database_migration_ms', val);

  Future<void> init() async {
    if (_store != null) return;
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    final isolateName = Isolate.current.debugName ?? '';
    final isSecondaryIsolate =
        isolateName.toLowerCase().contains('overlay') ||
        isolateName.toLowerCase().contains('companion');

    debugPrint(
      '[Storage] Initializing in isolate: "$isolateName" (isSecondaryIsolate: $isSecondaryIsolate)',
    );

    if (isSecondaryIsolate) {
      debugPrint(
        '[Storage] Bypassing initialization in secondary isolate: $isolateName',
      );
      return;
    }

    _initializing = true;
    _failed = false;
    final overallStopwatch = Stopwatch()..start();
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
      if (Directory(legacyStoreDir).existsSync() &&
          !Directory(storeDir).existsSync()) {
        debugPrint(
          '[Storage] Migrating database from legacy location: $legacyStoreDir to $storeDir',
        );
        final migrationStopwatch = Stopwatch()..start();
        try {
          Directory(storeDir).parent.createSync(recursive: true);
          Directory(legacyStoreDir).renameSync(storeDir);
          migrationDurationMs = migrationStopwatch.elapsedMilliseconds;
          debugPrint(
            '[Storage] Migration successful in ${migrationDurationMs}ms.',
          );
        } catch (e) {
          debugPrint(
            '[Storage] Migration failed: $e. Staying with existing paths.',
          );
        }
      }

      final activeStoreDir = Directory(storeDir).existsSync()
          ? storeDir
          : (Directory(legacyStoreDir).existsSync()
                ? legacyStoreDir
                : storeDir);

      activeDatabasePath = activeStoreDir;
      await diagnoseStorage(activeStoreDir);

      // Ensure the directory exists
      final dir = Directory(activeStoreDir);
      if (!dir.existsSync()) {
        debugPrint('[Storage] Creating store directory: $activeStoreDir');
        dir.createSync(recursive: true);
      }

      String? macosAppGroup;
      if (Platform.isMacOS) {
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          final packageName = packageInfo.packageName;
          if (packageName.endsWith('.dev')) {
            macosAppGroup = 'breakmate.dev';
          } else if (packageName.contains('breakmate')) {
            macosAppGroup = 'breakmate';
          } else if (packageName.isNotEmpty) {
            final shortName = packageName.split('.').last;
            macosAppGroup = shortName.length <= 19
                ? shortName
                : shortName.substring(0, 19);
          } else {
            macosAppGroup = 'breakmate';
          }
          debugPrint(
            '[Storage] Detected macOS bundle ID: $packageName -> mapped App Group: $macosAppGroup',
          );
        } catch (e) {
          debugPrint(
            '[Storage] Failed to fetch PackageInfo for macOS app group: $e',
          );
        }
      }

      debugPrint('[Storage] Opening ObjectBox store at $activeStoreDir...');
      final openStopwatch = Stopwatch()..start();
      try {
        _store = await openStore(
          directory: activeStoreDir,
          macosApplicationGroup: macosAppGroup,
        );
        openDurationMs = openStopwatch.elapsedMilliseconds;
        debugPrint(
          '[Storage] Store opened successfully in ${openDurationMs}ms.',
        );
      } catch (e, stack) {
        debugPrint('[Storage] Failed to open store: $e');
        debugPrint('[Storage] StackTrace: $stack');

        final errStr = e.toString().toLowerCase();
        final isLockError =
            errStr.contains('operation not permitted') ||
            errStr.contains('lock') ||
            errStr.contains('10199') ||
            errStr.contains('10101');
        final isSchemaError =
            errStr.contains('migration') ||
            errStr.contains('schema') ||
            errStr.contains('incompatible') ||
            errStr.contains('corrupt') ||
            errStr.contains('model');

        if (isLockError) {
          debugPrint(
            '[Storage] Attempting to clean up stale processes holding the database files...',
          );
          try {
            final dbFilePath = p.join(activeStoreDir, 'data.mdb');
            final lockFilePath = p.join(activeStoreDir, 'lock.mdb');

            final pids = <int>{};
            for (final path in [dbFilePath, lockFilePath, activeStoreDir]) {
              try {
                final result = await Process.run('lsof', ['-t', path]);
                if (result.exitCode == 0) {
                  final stdoutStr = result.stdout.toString().trim();
                  if (stdoutStr.isNotEmpty) {
                    for (final line in stdoutStr.split('\n')) {
                      final parsedPid = int.tryParse(line.trim());
                      if (parsedPid != null && parsedPid != pid) {
                        pids.add(parsedPid);
                      }
                    }
                  }
                }
              } catch (_) {}
            }

            if (pids.isNotEmpty) {
              debugPrint(
                '[Storage] Found stale processes holding DB files: $pids. Terminating them...',
              );
              for (final stalePid in pids) {
                try {
                  await Process.run('kill', ['-9', stalePid.toString()]);
                  debugPrint(
                    '[Storage] Successfully terminated stale PID $stalePid.',
                  );
                } catch (killErr) {
                  debugPrint(
                    '[Storage] Failed to kill PID $stalePid: $killErr',
                  );
                }
              }
              // Wait for OS to release files
              await Future.delayed(const Duration(milliseconds: 800));
            }

            final lockFile = File(lockFilePath);
            if (lockFile.existsSync()) {
              try {
                lockFile.deleteSync();
                debugPrint(
                  '[Storage] Deleted stale lock.mdb after process cleanup.',
                );
              } catch (delErr) {
                debugPrint('[Storage] Failed to delete lock.mdb: $delErr');
              }
            }
            openStopwatch.reset();
            _store = await openStore(
              directory: activeStoreDir,
              macosApplicationGroup: macosAppGroup,
            );
            openDurationMs = openStopwatch.elapsedMilliseconds;
            debugPrint(
              '[Storage] Store opened after cleanup in ${openDurationMs}ms.',
            );
          } catch (retryError) {
            debugPrint('[Storage] Cleanup retry failed: $retryError');
          }
        }

        if (_store == null && isSchemaError) {
          debugPrint(
            '[Storage] Incompatible or corrupted database detected. Attempting database reset...',
          );
          try {
            final dir = Directory(activeStoreDir);
            if (dir.existsSync()) {
              dir.deleteSync(recursive: true);
              dir.createSync(recursive: true);
              debugPrint('[Storage] Database directory deleted and recreated.');
            }
            openStopwatch.reset();
            _store = await openStore(
              directory: activeStoreDir,
              macosApplicationGroup: macosAppGroup,
            );
            openDurationMs = openStopwatch.elapsedMilliseconds;
            debugPrint(
              '[Storage] Store opened successfully after database reset in ${openDurationMs}ms.',
            );
          } catch (resetError) {
            debugPrint('[Storage] Database reset failed: $resetError');
          }
        }

        if (_store == null) {
          // Fallback: try Documents directory if Support failed (for some reason)
          if (activeStoreDir != legacyStoreDir) {
            debugPrint(
              '[Storage] Attempting fallback to legacy location $legacyStoreDir...',
            );
            try {
              Directory(legacyStoreDir).createSync(recursive: true);
              openStopwatch.reset();
              _store = await openStore(
                directory: legacyStoreDir,
                macosApplicationGroup: macosAppGroup,
              );
              openDurationMs = openStopwatch.elapsedMilliseconds;
              activeDatabasePath = legacyStoreDir;
            } catch (_) {}
          }

          if (_store == null) {
            // Last resort: temporary directory (will lose data on OS cleanup)
            try {
              final tempDir = await getTemporaryDirectory();
              final fallbackPath = p.join(tempDir.path, 'breakmate_fallback');
              debugPrint(
                'WARNING:\nRunning on temporary storage.\nSettings may not persist.',
              );
              Directory(fallbackPath).createSync(recursive: true);
              openStopwatch.reset();
              _store = await openStore(
                directory: fallbackPath,
                macosApplicationGroup: macosAppGroup,
              );
              openDurationMs = openStopwatch.elapsedMilliseconds;
              activeDatabasePath = fallbackPath;
              debugPrint('[Storage] Fallback store opened successfully.');
            } catch (fallbackError) {
              debugPrint(
                '[Storage] FATAL: All storage options failed: $fallbackError',
              );
              _failed = true;
              diagnoseAndLogFailure(activeStoreDir);
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
        diagnoseAndLogFailure(activeStoreDir);
      }
    } catch (e) {
      debugPrint('[Storage] Unexpected error during init: $e');
      _failed = true;
      diagnoseAndLogFailure(activeDatabasePath ?? '');
    } finally {
      _initializing = false;
      initDurationMs = overallStopwatch.elapsedMilliseconds;
    }
  }

  void close() {
    if (_store != null) {
      debugPrint('[Storage] Closing ObjectBox store cleanly...');
      _store!.close();
      _store = null;
      settingsBox = null;
      dailyStatsBox = null;
      globalStatsBox = null;
      companionPreferencesBox = null;
      kvBox = null;
      debugPrint('[Storage] Store closed cleanly.');
    }
  }

  void diagnoseAndLogFailure(String storeDir) {
    debugPrint('=== 🚨 STORAGE INITIALIZATION FAILURE DIAGNOSTICS ===');

    // 1. Initialization order issue
    debugPrint('[Diagnostics] 1. Initialization Order Check:');
    debugPrint('   - StorageService._initializing: $_initializing');
    debugPrint('   - StorageService._store != null: ${_store != null}');

    // 2. Existing process ownership
    debugPrint('[Diagnostics] 2. Existing Process Ownership Check:');
    debugPrint('   - Current Process ID: $pid');

    // 3. Secondary isolate access
    final isolateName = Isolate.current.debugName ?? '';
    final isSecondaryIsolate =
        isolateName.toLowerCase().contains('overlay') ||
        isolateName.toLowerCase().contains('companion');
    debugPrint('[Diagnostics] 3. Secondary Isolate Check:');
    debugPrint('   - Isolate Name: "$isolateName"');
    debugPrint('   - Is Secondary Isolate: $isSecondaryIsolate');

    // 4. Temporary storage fallback
    debugPrint('[Diagnostics] 4. Temporary Storage Fallback Check:');
    debugPrint('   - Active database path: $activeDatabasePath');
    final isTemp = activeDatabasePath?.contains('temporary') ?? false;
    debugPrint('   - Is Running on Temporary Storage: $isTemp');
    if (isTemp) {
      debugPrint(
        'WARNING:\nRunning on temporary storage.\nSettings may not persist.',
      );
    }

    // 5. ObjectBox open failure
    debugPrint('[Diagnostics] 5. ObjectBox Open Failure Check:');
    debugPrint('   - StorageService._failed: $_failed');

    // 6. Database corruption
    debugPrint('[Diagnostics] 6. Database Corruption Check:');
    if (storeDir.isNotEmpty) {
      final dbFile = File(p.join(storeDir, 'data.mdb'));
      debugPrint('   - Database file exists: ${dbFile.existsSync()}');
      if (dbFile.existsSync()) {
        try {
          debugPrint('   - Database file size: ${dbFile.lengthSync()} bytes');
        } catch (e) {
          debugPrint('   - Database file read error: $e');
        }
      }
    }

    // 7. Lock-file conflict
    debugPrint('[Diagnostics] 7. Lock-file Conflict Check:');
    if (storeDir.isNotEmpty) {
      final lockFile = File(p.join(storeDir, 'lock.mdb'));
      debugPrint('   - Lock file exists: ${lockFile.existsSync()}');
      if (lockFile.existsSync()) {
        debugPrint(
          '   - Lock file is present, potential locking conflict with another running instance.',
        );
      }
    }

    debugPrint('=====================================================');
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
      if (activeDatabasePath != null) {
        final file = File(p.join(activeDatabasePath!, 'data.mdb'));
        if (await file.exists()) {
          return await file.length();
        }
      }
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
    // Always mirror to SimplePrefs
    SimplePrefs.instance.setInt(key, value);

    if (kvBox == null) return false;
    final existing = _getKv(key);
    if (existing != null) {
      existing.value = value.toString();
      kvBox!.put(existing);
    } else {
      kvBox!.put(
        KeyValueRecord(key: key, value: value.toString(), type: 'int'),
      );
    }
    return true;
  }

  int getInt(String key, {int defaultValue = 0}) {
    if (kvBox == null) {
      return SimplePrefs.instance.getInt(key, defaultValue: defaultValue);
    }
    final kv = _getKv(key);
    if (kv != null && kv.type == 'int') {
      return int.tryParse(kv.value) ?? defaultValue;
    }
    return SimplePrefs.instance.getInt(key, defaultValue: defaultValue);
  }

  Future<bool> setBool(String key, bool value) async {
    // Always mirror to SimplePrefs
    SimplePrefs.instance.setBool(key, value);

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
    if (kvBox == null) {
      return SimplePrefs.instance.getBool(key, defaultValue: defaultValue);
    }
    final kv = _getKv(key);
    if (kv != null && kv.type == 'bool') {
      return kv.value == 'true';
    }
    return SimplePrefs.instance.getBool(key, defaultValue: defaultValue);
  }

  Future<bool> setString(String key, String value) async {
    // Always mirror to SimplePrefs
    SimplePrefs.instance.setString(key, value);

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
    if (kvBox == null) {
      return SimplePrefs.instance.getString(key, defaultValue: defaultValue);
    }
    final kv = _getKv(key);
    if (kv != null && kv.type == 'string') {
      return kv.value;
    }
    return SimplePrefs.instance.getString(key, defaultValue: defaultValue);
  }

  Future<bool> setDouble(String key, double value) async {
    // Always mirror to SimplePrefs
    SimplePrefs.instance.setDouble(key, value);

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
    if (kvBox == null) {
      return SimplePrefs.instance.getDouble(key, defaultValue: defaultValue);
    }
    final kv = _getKv(key);
    if (kv != null && kv.type == 'double') {
      return double.tryParse(kv.value) ?? defaultValue;
    }
    return SimplePrefs.instance.getDouble(key, defaultValue: defaultValue);
  }
}
