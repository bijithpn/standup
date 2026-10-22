import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/errors/app_exception.dart';

class SimplePrefs {
  SimplePrefs._();

  static final SimplePrefs instance = SimplePrefs._();

  String? _filePath;
  Map<String, dynamic> _data = {};

  bool get isReady => _filePath != null;

  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _filePath = p.join(dir.path, 'breakmate_critical.json');
      debugPrint('[SimplePrefs] Path: $_filePath');
      _load();
    } catch (e, st) {
      ErrorHandler().handleError(
        e,
        st,
        type: AppErrorType.storage,
        message: 'SimplePrefs init() failed',
      );
    }
  }

  void _load() {
    try {
      final file = File(_filePath!);
      if (file.existsSync()) {
        final raw = file.readAsStringSync();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _data = decoded;
          debugPrint(
            '[SimplePrefs] Loaded ${_data.length} keys: ${_data.keys.toList()}',
          );
          return;
        }
      }
      debugPrint('[SimplePrefs] No existing data file — starting fresh.');
    } catch (e, st) {
      ErrorHandler().handleError(
        e,
        st,
        type: AppErrorType.storage,
        message: 'SimplePrefs _load() error. Starting fresh.',
      );
      _data = {};
    }
  }

  Timer? _writeTimer;
  bool _dirty = false;

  /// Queues a write. Settings are saved as dozens of keys in a row, and
  /// writing, fsyncing and renaming the whole file for each one blocked the UI
  /// for hundreds of milliseconds on every toggle. A burst now costs one write.
  void _persist() {
    if (_filePath == null) return;
    _dirty = true;
    _writeTimer ??= Timer(const Duration(milliseconds: 120), flush);
  }

  /// Writes any pending changes now. Called on shutdown, and by anything that
  /// needs the file to be current.
  void flush() {
    _writeTimer?.cancel();
    _writeTimer = null;
    if (!_dirty) return;
    _dirty = false;
    _writeNow();
  }

  void _writeNow() {
    if (_filePath == null) return;
    try {
      final json = jsonEncode(_data);
      final tmp = File('$_filePath.tmp');
      tmp.writeAsStringSync(json, flush: true);
      tmp.renameSync(_filePath!);
    } catch (e, st) {
      ErrorHandler().handleError(
        e,
        st,
        type: AppErrorType.storage,
        message: 'SimplePrefs _persist() error',
      );
    }
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final v = _data[key];
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return defaultValue;
  }

  void setBool(String key, bool value) {
    if (_data[key] == value) return;
    _data[key] = value;
    _persist();
    debugPrint('[SimplePrefs] setBool($key, $value) persisted.');
  }

  String getString(String key, {String defaultValue = ''}) {
    final v = _data[key];
    if (v is String) return v;
    return defaultValue;
  }

  void setString(String key, String value) {
    if (_data[key] == value) return;
    _data[key] = value;
    _persist();
  }

  int getInt(String key, {int defaultValue = 0}) {
    final v = _data[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  void setInt(String key, int value) {
    if (_data[key] == value) return;
    _data[key] = value;
    _persist();
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    final v = _data[key];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  void setDouble(String key, double value) {
    if (_data[key] == value) return;
    _data[key] = value;
    _persist();
  }

  void remove(String key) {
    _data.remove(key);
    _persist();
  }

  void clear() {
    _data.clear();
    _persist();
  }
}
