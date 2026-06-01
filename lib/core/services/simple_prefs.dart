import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// A lightweight, file-based key-value store for critical one-way flags.
///
/// Intentionally separate from ObjectBox so that if the database fails to open
/// or writes to a different path, these values are still reliably persisted.
///
/// Uses a JSON file at `<ApplicationSupportDirectory>/breakmate_critical.json`.
/// Writes are synchronous and atomic (temp-file + rename) so they survive
/// partial writes / process kills.
class SimplePrefs {
  SimplePrefs._();

  static final SimplePrefs instance = SimplePrefs._();

  String? _filePath;
  Map<String, dynamic> _data = {};

  bool get isReady => _filePath != null;

  // ── Initialization ──────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _filePath = p.join(dir.path, 'breakmate_critical.json');
      debugPrint('[SimplePrefs] Path: $_filePath');
      _load();
    } catch (e) {
      debugPrint('[SimplePrefs] init() failed: $e');
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
          debugPrint('[SimplePrefs] Loaded ${_data.length} keys: ${_data.keys.toList()}');
          return;
        }
      }
      debugPrint('[SimplePrefs] No existing data file — starting fresh.');
    } catch (e) {
      debugPrint('[SimplePrefs] _load() error: $e. Starting fresh.');
      _data = {};
    }
  }

  void _persist() {
    if (_filePath == null) return;
    try {
      final json = jsonEncode(_data);
      // Write to a temp file then rename for atomicity.
      final tmp = File('$_filePath.tmp');
      tmp.writeAsStringSync(json, flush: true);
      tmp.renameSync(_filePath!);
    } catch (e) {
      debugPrint('[SimplePrefs] _persist() error: $e');
    }
  }

  // ── API ─────────────────────────────────────────────────────────────────────

  bool getBool(String key, {bool defaultValue = false}) {
    final v = _data[key];
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return defaultValue;
  }

  void setBool(String key, bool value) {
    _data[key] = value;
    _persist();
    debugPrint('[SimplePrefs] setBool($key, $value) ✓');
  }

  String getString(String key, {String defaultValue = ''}) {
    final v = _data[key];
    if (v is String) return v;
    return defaultValue;
  }

  void setString(String key, String value) {
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
    _data[key] = value;
    _persist();
  }

  void remove(String key) {
    _data.remove(key);
    _persist();
  }
}
