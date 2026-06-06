import 'dart:convert';
import 'dart:io';

import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

/// Atomic settings I/O service for [PetConfigV2].
///
/// Responsibilities:
/// - [loadSync]: Read and parse the platform-appropriate config file before
///   the first tick. On any error, apply defaults, log, and schedule a write.
/// - [scheduleWrite]: Set a dirty flag; the actual write is deferred to the
///   next [flushPendingWrite] call (i.e., at the start of the next tick).
/// - [flushPendingWrite]: Perform an atomic write (`.tmp` → rename) if dirty.
/// - [flush]: Force-flush immediately (used on app termination).
///
/// Requirement references: 11.1, 11.2, 11.3, 11.4, 11.6, 11.7.
class SettingsPersistence {
  SettingsPersistence({AppLogger? logger, String? configPathOverride})
    : _logger = logger ?? AppLogger(),
      _configPathOverride = configPathOverride;

  final AppLogger _logger;
  final String? _configPathOverride;

  // ---- internal state ------------------------------------------------------

  /// Cached config kept in memory for the lifetime of the session.
  PetConfigV2 _config = PetConfigV2.defaults();

  /// Whether an unwritten change is pending.
  bool _dirty = false;

  /// Config snapshot to write on next [flushPendingWrite].
  PetConfigV2? _pending;

  // ---- config file path ----------------------------------------------------

  /// Returns the platform-appropriate path to `pet_config_v2.json`.
  ///
  /// Can be overridden via [configPathOverride] for testing.
  String get _configPath {
    if (_configPathOverride != null) return _configPathOverride;
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Library/Application Support/breakmate/pet_config_v2.json';
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return '$appData\\breakmate\\pet_config_v2.json';
    }
    throw UnsupportedError(
      'SettingsPersistence: unsupported platform. '
      'Only macOS and Windows are supported.',
    );
  }

  // ---- public API ----------------------------------------------------------

  /// Load settings synchronously at launch, before the first tick.
  ///
  /// On [FormatException] or [FileSystemException] (missing or corrupt file):
  /// 1. Apply [PetConfigV2.defaults()].
  /// 2. Log the error.
  /// 3. Immediately schedule a write of the defaults so the file is created /
  ///    repaired on the first call to [flushPendingWrite].
  ///
  /// Requirement 11.1, 11.2.
  PetConfigV2 loadSync() {
    final path = _configPath;
    try {
      final file = File(path);
      final contents = file.readAsStringSync();
      final decoded = jsonDecode(contents) as Map<String, dynamic>;
      _config = PetConfigV2.fromJson(decoded);
      _logger.info('SettingsPersistence: loaded config from $path');
    } on FileSystemException catch (e) {
      _logger.error(
        'SettingsPersistence: could not read config file "$path": '
        '${e.message} (${e.osError?.message ?? "no OS error"}). '
        'Applying defaults.',
      );
      _config = PetConfigV2.defaults();
      scheduleWrite(_config);
    } on FormatException catch (e) {
      _logger.error(
        'SettingsPersistence: config file "$path" contains invalid JSON: '
        '${e.message}. Applying defaults.',
      );
      _config = PetConfigV2.defaults();
      scheduleWrite(_config);
    }
    return _config;
  }

  /// Schedule an atomic write of [config].
  ///
  /// Sets the dirty flag; the write itself is deferred to [flushPendingWrite],
  /// which is called at the start of each tick (requirement 11.3).
  void scheduleWrite(PetConfigV2 config) {
    _config = config;
    _pending = config;
    _dirty = true;
  }

  /// Flush a pending write if dirty.
  ///
  /// Performs an atomic write:
  /// 1. Serialize [_pending] to JSON.
  /// 2. Write to `<path>.tmp`.
  /// 3. Rename `.tmp` → `<path>`.
  ///
  /// On [FileSystemException]: log with reason and path, then clear the dirty
  /// flag and continue — the engine must not crash (requirement 11.7).
  ///
  /// Called from `CompanionGame.update()` at the start of each tick.
  void flushPendingWrite() {
    if (!_dirty || _pending == null) return;
    _atomicWrite(_pending!);
    _dirty = false;
    _pending = null;
  }

  /// Force-flush any pending write immediately.
  ///
  /// Intended for use during app termination (e.g., from
  /// `CompanionGame.onRemove()` or the shutdown coordinator).
  ///
  /// Requirement 11.3.
  Future<void> flush() async {
    if (!_dirty || _pending == null) return;
    _atomicWrite(_pending!);
    _dirty = false;
    _pending = null;
  }

  /// The currently loaded (in-memory) configuration.
  PetConfigV2 get current => _config;

  // ---- private helpers -----------------------------------------------------

  /// Perform the two-step atomic write: `.tmp` then rename.
  ///
  /// Requirement 11.6.
  void _atomicWrite(PetConfigV2 config) {
    final path = _configPath;
    final tmpPath = '$path.tmp';
    try {
      final jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(config.toJson());

      // Ensure parent directory exists before writing.
      final dir = File(path).parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Write to .tmp first (requirement 11.6 — atomic write step 1).
      File(tmpPath).writeAsStringSync(jsonString, flush: true);

      // Rename .tmp → target (atomic swap on most platforms).
      File(tmpPath).renameSync(path);

      _logger.info('SettingsPersistence: config written to $path');
    } on FileSystemException catch (e) {
      // Requirement 11.7: log error, do not crash.
      _logger.error(
        'SettingsPersistence: failed to write config to "$path": '
        '${e.message} (${e.osError?.message ?? "no OS error"}). '
        'Continuing with in-memory state.',
      );
      // Attempt to clean up the .tmp file if it exists.
      try {
        final tmpFile = File(tmpPath);
        if (tmpFile.existsSync()) tmpFile.deleteSync();
      } catch (_) {
        // Best-effort cleanup — ignore secondary errors.
      }
    }
  }
}
