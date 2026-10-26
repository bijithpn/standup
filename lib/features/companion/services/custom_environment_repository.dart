import 'dart:convert';
import 'dart:io';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/domain/environment_theme_config.dart';

import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/errors/app_exception.dart';

// Persists the user's list of custom EnvironmentThemeConfig entries as a JSON
// sidecar file alongside pet_config_v2.json. Follows the same atomic-write
// pattern as SettingsPersistence.
class CustomEnvironmentRepository {
  CustomEnvironmentRepository({AppLogger? logger})
    : _logger = logger ?? AppLogger();

  final AppLogger _logger;
  List<CustomEnvironmentTheme> _themes = [];

  List<CustomEnvironmentTheme> get themes => List.unmodifiable(_themes);

  String get _configPath {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Library/Application Support/breakmate/custom_environments.json';
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return '$appData\\breakmate\\custom_environments.json';
    }
    if (Platform.isLinux) {
      final configHome =
          Platform.environment['XDG_CONFIG_HOME'] ??
          '${Platform.environment['HOME'] ?? ''}/.config';
      return '$configHome/breakmate/custom_environments.json';
    }
    throw UnsupportedError(
      'CustomEnvironmentRepository: unsupported platform.',
    );
  }

  // Synchronous initial load. Returns immediately with an empty list if the
  // file does not yet exist.
  List<CustomEnvironmentTheme> loadSync() {
    final path = _configPath;
    try {
      final file = File(path);
      if (!file.existsSync()) {
        _themes = [];
        return _themes;
      }
      final contents = file.readAsStringSync();
      final decoded = jsonDecode(contents);
      if (decoded is! List) {
        _themes = [];
        return _themes;
      }
      _themes = decoded
          .whereType<Map<String, dynamic>>()
          .map(CustomEnvironmentTheme.fromJson)
          .toList();
      _logger.info(
        'CustomEnvironmentRepository: loaded ${_themes.length} custom themes.',
      );
    } on FileSystemException catch (e) {
      _logger.error(
        'CustomEnvironmentRepository: could not read "$path": ${e.message}.',
      );
      _themes = [];
    } on FormatException catch (e) {
      _logger.error(
        'CustomEnvironmentRepository: invalid JSON in "$path": ${e.message}.',
      );
      _themes = [];
    } finally {
      _syncToDomainThemes();
    }
    return _themes;
  }

  // Persist [themes] atomically. Replaces the in-memory list on success.
  Future<void> save(List<CustomEnvironmentTheme> themes) async {
    _themes = List.of(themes);
    await _atomicWrite(_themes);
  }

  // Adds or replaces the theme with matching id and persists.
  Future<void> upsert(CustomEnvironmentTheme theme) async {
    final index = _themes.indexWhere((t) => t.id == theme.id);
    if (index >= 0) {
      _themes[index] = theme;
    } else {
      _themes.add(theme);
    }
    await _atomicWrite(_themes);
  }

  // Removes the theme by id and persists.
  Future<void> delete(String id) async {
    _themes.removeWhere((t) => t.id == id);
    await _atomicWrite(_themes);
  }

  Future<void> _atomicWrite(List<CustomEnvironmentTheme> themes) async {
    final path = _configPath;
    final tmpPath = '$path.tmp';
    try {
      final jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(themes.map((t) => t.toJson()).toList());
      final dir = File(path).parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      final tmpFile = File(tmpPath);
      await tmpFile.writeAsString(jsonString, flush: true);
      await tmpFile.rename(path);
      _syncToDomainThemes();
      _logger.info(
        'CustomEnvironmentRepository: saved ${themes.length} custom themes.',
      );
    } catch (e, st) {
      ErrorHandler().handleError(
        e,
        st,
        type: AppErrorType.storage,
        message: 'Failed to write custom environments to "$path"',
      );
      try {
        final tmp = File(tmpPath);
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  void _syncToDomainThemes() {
    EnvironmentThemeConfig.customThemes = _themes
        .map((t) => t.toEnvironmentThemeConfig())
        .toList();
  }
}
