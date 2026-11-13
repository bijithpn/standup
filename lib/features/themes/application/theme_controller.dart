import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import '../domain/app_theme_preset.dart';

/// Owns the selected theme preset and custom accent, persists them, and pushes them into AppTheme and the native window effect.
class ThemeController extends ChangeNotifier {
  final StorageService _storage;
  static const String _kPresetStorageKey = 'app_theme_preset_id';
  static const String _kCustomAccentStorageKey = 'app_theme_custom_accent';

  AppThemePreset _currentPreset = AppThemePreset.nordicSlate;
  Color? _customAccent;
  Timer? _autoResolveTimer;

  ThemeController({required StorageService storage}) : _storage = storage {
    _loadFromStorage();
  }

  AppThemePreset get currentPreset => _currentPreset;
  Color get activeAccent => _customAccent ?? AppTheme.activePreset.accent;
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
    _applyCurrentPreset();
  }

  Future<void> setPreset(String presetId) async {
    final preset = AppThemePreset.findById(presetId);
    _currentPreset = preset;
    _applyCurrentPreset();
    notifyListeners();
    unawaited(_storage.setString(_kPresetStorageKey, preset.id));
  }

  Future<void> setCustomAccent(Color? color) async {
    _customAccent = color;
    AppTheme.applyCustomAccent(_customAccent);
    notifyListeners();
    unawaited(
      _storage.setInt(_kCustomAccentStorageKey, color?.toARGB32() ?? 0),
    );
  }

  Future<void> resetToDefault() async {
    _currentPreset = AppThemePreset.nordicSlate;
    _customAccent = null;
    _applyCurrentPreset();
    notifyListeners();
    unawaited(
      _storage.setString(_kPresetStorageKey, AppThemePreset.nordicSlate.id),
    );
    unawaited(_storage.setInt(_kCustomAccentStorageKey, 0));
  }

  // The Auto preset has no fixed look; it re-resolves light/dark every 15 minutes.
  void _applyCurrentPreset() {
    _autoResolveTimer?.cancel();
    _autoResolveTimer = null;

    if (_currentPreset.id == AppThemePreset.auto.id) {
      unawaited(_resolveAndApplyAuto());

      _autoResolveTimer = Timer.periodic(
        const Duration(minutes: 15),
        (_) => unawaited(_resolveAndApplyAuto()),
      );
    } else {
      AppTheme.applyPreset(_currentPreset, customAccent: _customAccent);
      unawaited(_applyWindowEffect(_currentPreset));
    }
  }

  Future<void> _resolveAndApplyAuto() async {
    final resolved = await _resolveAutoPreset();
    AppTheme.applyPreset(resolved, customAccent: _customAccent);
    unawaited(_applyWindowEffect(resolved));
    notifyListeners();
  }

  // Prefers the OS appearance; falls back to time of day (dark from 19:00 to 07:00).
  Future<AppThemePreset> _resolveAutoPreset() async {
    try {
      final appearance = await NativeBridge.getAppearance();
      if (appearance == 'light') return AppThemePreset.nordicSlate;
      if (appearance == 'dark') return AppThemePreset.solarizedAmber;
    } catch (_) {}

    final hour = DateTime.now().hour;
    final isEvening = hour >= 19 || hour < 7;
    return isEvening
        ? AppThemePreset.solarizedAmber
        : AppThemePreset.nordicSlate;
  }

  // Vibrancy/acrylic only applies to the native-vibrancy preset on macOS/Windows.
  Future<void> _applyWindowEffect(AppThemePreset preset) async {
    if (!Platform.isMacOS && !Platform.isWindows) return;
    try {
      if (preset.id == AppThemePreset.nativeVibrancy.id) {
        await Window.setEffect(
          effect: Platform.isMacOS
              ? WindowEffect.sidebar
              : WindowEffect.acrylic,
          dark: preset.isDark,
        );
      } else {
        await Window.setEffect(effect: WindowEffect.disabled);
      }
    } catch (e) {
      debugPrint('ThemeController: Window.setEffect failed: $e');
    }
  }

  @override
  void dispose() {
    _autoResolveTimer?.cancel();
    super.dispose();
  }
}
