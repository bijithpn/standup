import 'dart:convert';
import 'dart:io';

import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:flutter/foundation.dart';

import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/errors/app_exception.dart';

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
    if (Platform.isLinux) {
      final configHome =
          Platform.environment['XDG_CONFIG_HOME'] ??
          '${Platform.environment['HOME'] ?? ''}/.config';
      return '$configHome/breakmate/pet_config_v2.json';
    }
    throw UnsupportedError(
      'SettingsPersistence: unsupported platform. '
      'Only macOS, Windows and Linux are supported.',
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

  Future<void> flushPendingWrite() async {
    if (!_dirty || _pending == null) return;
    final configToWrite = _pending!;
    _dirty = false;
    _pending = null;
    await _atomicWrite(configToWrite);
  }

  Future<void> flush() async {
    await flushPendingWrite();
  }

  PetConfigV2 get current => _config;

  AvatarDefinition? get avatarDefinition => _config.avatarDefinition;

  void saveAvatarDefinition(AvatarDefinition definition) {
    scheduleWrite(
      _config.copyWith(
        themeId: 'avatar_${definition.species.name}',
        avatarDefinition: definition,
      ),
    );
  }

  Future<void> _atomicWrite(PetConfigV2 config) async {
    final path = _configPath;
    final tmpPath = '$path.tmp';
    try {
      final jsonString = await MapIsolateEncoder.encode(config.toJson());

      final dir = File(path).parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final tmpFile = File(tmpPath);
      await tmpFile.writeAsString(jsonString, flush: true);

      await tmpFile.rename(path);

      _logger.info('SettingsPersistence: config written to $path');
    } catch (e, st) {
      ErrorHandler().handleError(
        e,
        st,
        type: AppErrorType.storage,
        message: 'Failed to write config to "$path"',
      );
      try {
        final tmpFile = File(tmpPath);
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {}
    }
  }
}

class MapIsolateEncoder {
  static Future<String> encode(Map<String, dynamic> map) async {
    return compute(_doEncode, map);
  }

  static String _doEncode(Map<String, dynamic> map) {
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}
