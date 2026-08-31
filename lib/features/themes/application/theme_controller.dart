import 'package:flutter/material.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import '../domain/app_theme_preset.dart';

class ThemeController extends ChangeNotifier {
  final StorageService _storage;
  static const String _kPresetStorageKey = 'app_theme_preset_id';
  static const String _kCustomAccentStorageKey = 'app_theme_custom_accent';

  AppThemePreset _currentPreset = AppThemePreset.nordicSlate;
  Color? _customAccent;

  ThemeController({required StorageService storage}) : _storage = storage {
    _loadFromStorage();
  }

  AppThemePreset get currentPreset => _currentPreset;
  Color get activeAccent => _customAccent ?? _currentPreset.accent;
  Color? get customAccent => _customAccent;
  List<AppThemePreset> get availablePresets => AppThemePreset.allPresets;

  void _loadFromStorage() {
    try {
      final savedId = _storage.getString(_kPresetStorageKey, defaultValue: '');
      if (savedId.isNotEmpty) {
        _currentPreset = AppThemePreset.findById(savedId);
      }

      final savedAccentInt = _storage.getInt(
        _kCustomAccentStorageKey,
        defaultValue: 0,
      );
      if (savedAccentInt != 0) {
        _customAccent = Color(savedAccentInt);
      }
    } catch (_) {
      _currentPreset = AppThemePreset.nordicSlate;
    }
    AppTheme.applyPreset(_currentPreset, customAccent: _customAccent);
  }

  Future<void> setPreset(String presetId) async {
    final preset = AppThemePreset.findById(presetId);
    _currentPreset = preset;
    AppTheme.applyPreset(_currentPreset, customAccent: _customAccent);
    notifyListeners();
    await _storage.setString(_kPresetStorageKey, preset.id);
  }

  Future<void> setCustomAccent(Color? color) async {
    _customAccent = color;
    AppTheme.applyCustomAccent(_customAccent);
    notifyListeners();
    await _storage.setInt(_kCustomAccentStorageKey, color?.toARGB32() ?? 0);
  }

  Future<void> resetToDefault() async {
    _currentPreset = AppThemePreset.nordicSlate;
    _customAccent = null;
    AppTheme.applyPreset(_currentPreset, customAccent: _customAccent);
    notifyListeners();
    await _storage.setString(_kPresetStorageKey, AppThemePreset.nordicSlate.id);
    await _storage.setInt(_kCustomAccentStorageKey, 0);
  }
}
