import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import '../domain/app_theme_preset.dart';

class ThemeController extends ChangeNotifier {
  final StorageService _storage;
  static const String _kPresetStorageKey = 'app_theme_preset_id';
  static const String _kCustomAccentStorageKey = 'app_theme_custom_accent';

  /// The user's selected preset — may be the [AppThemePreset.auto] meta
  /// preset, in which case [AppTheme.activePreset] holds the *resolved*
  /// concrete preset actually being rendered.
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

  /// Applies [_currentPreset], resolving the [AppThemePreset.auto] meta
  /// preset to a concrete palette and (re-)arming its periodic re-check.
  void _applyCurrentPreset() {
    _autoResolveTimer?.cancel();
    _autoResolveTimer = null;

    if (_currentPreset.id == AppThemePreset.auto.id) {
      unawaited(_resolveAndApplyAuto());
      // Circadian/system-appearance switch is coarse — a 15 min recheck is
      // frequent enough to catch both a day/night crossing and the user
      // toggling their OS appearance mid-session.
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

  /// Nordic Slate ↔ Solarized Amber, chosen by the OS's reported appearance
  /// where available (`getAppearance()` is implemented on both macOS and
  /// Windows already), falling back to a time-of-day circadian split.
  Future<AppThemePreset> _resolveAutoPreset() async {
    try {
      final appearance = await NativeBridge.getAppearance();
      if (appearance == 'light') return AppThemePreset.nordicSlate;
      if (appearance == 'dark') return AppThemePreset.solarizedAmber;
    } catch (_) {
      // Fall through to the time-of-day heuristic below.
    }

    final hour = DateTime.now().hour;
    final isEvening = hour >= 19 || hour < 7;
    return isEvening
        ? AppThemePreset.solarizedAmber
        : AppThemePreset.nordicSlate;
  }

  /// Syncs the main window's native blur/vibrancy with the selected preset.
  /// Only [AppThemePreset.nativeVibrancy] requests OS blur; every other
  /// preset restores a fully opaque window. `flutter_acrylic` is already a
  /// dependency used elsewhere for overlay transparency, so this reuses it
  /// rather than adding new platform surface.
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
