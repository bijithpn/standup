import 'dart:convert';
import 'dart:io';

import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

class SettingsPersistence {
  SettingsPersistence({AppLogger? logger, String? configPathOverride})
    : _logger = logger ?? AppLogger(),
      _configPathOverride = configPathOverride;

  final AppLogger _logger;
  final String? _configPathOverride;

  PetConfigV2 _config = PetConfigV2.defaults();

  bool _dirty = false;

  PetConfigV2? _pending;

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

  void scheduleWrite(PetConfigV2 config) {
    _config = config;
    _pending = config;
    _dirty = true;
  }

  void flushPendingWrite() {
    if (!_dirty || _pending == null) return;
    _atomicWrite(_pending!);
    _dirty = false;
    _pending = null;
  }

  Future<void> flush() async {
    if (!_dirty || _pending == null) return;
    _atomicWrite(_pending!);
    _dirty = false;
    _pending = null;
  }

  PetConfigV2 get current => _config;

  void _atomicWrite(PetConfigV2 config) {
    final path = _configPath;
    final tmpPath = '$path.tmp';
    try {
      final jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(config.toJson());

      final dir = File(path).parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      File(tmpPath).writeAsStringSync(jsonString, flush: true);

      File(tmpPath).renameSync(path);

      _logger.info('SettingsPersistence: config written to $path');
    } on FileSystemException catch (e) {
      _logger.error(
        'SettingsPersistence: failed to write config to "$path": '
        '${e.message} (${e.osError?.message ?? "no OS error"}). '
        'Continuing with in-memory state.',
      );
      try {
        final tmpFile = File(tmpPath);
        if (tmpFile.existsSync()) tmpFile.deleteSync();
      } catch (_) {
      }
    }
  }
}
