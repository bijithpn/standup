import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/features/settings/settings_repository.dart';

class CompanionOverlayController extends ChangeNotifier {
  final SettingsRepository _settingsRepo;

  bool _companionEnabled = false;
  String _companionCatTheme = 'grey_cat';
  String _companionPetName = 'Mochi';
  double _companionScale = 6.0;
  bool _companionClickThrough = false;

  CompanionOverlayController({
    required SettingsRepository settingsRepo,
  }) : _settingsRepo = settingsRepo;

  bool get companionEnabled => _companionEnabled;
  String get companionCatTheme => _companionCatTheme;
  String get companionPetName => _companionPetName;
  double get companionScale => _companionScale;
  bool get companionClickThrough => _companionClickThrough;

  /// Initializes the controller and synchronizes initial native window state if enabled.
  Future<void> init() async {
    final settings = _settingsRepo.currentSettings;
    
    // Read persisted settings (using dynamically added parameters on SettingsModel)
    _companionEnabled = settings.companionEnabled;
    _companionCatTheme = settings.companionCatTheme;
    _companionPetName = settings.companionPetName;
    _companionScale = settings.companionScale;
    _companionClickThrough = settings.companionClickThrough;

    if (_companionEnabled && Platform.isMacOS) {
      await _syncToNativeSpawn();
    }
  }

  /// Helper to invoke native show panel with initialized config.
  Future<void> _syncToNativeSpawn() async {
    if (!Platform.isMacOS) return;
    await MacOSBridge.showCompanion({
      'themeId': _companionCatTheme,
      'petName': _companionPetName,
      'scale': _companionScale,
      'clickThrough': _companionClickThrough,
    });
  }

  /// Toggles whether the desktop pet companion window is visible.
  Future<void> toggleCompanion(bool enabled) async {
    if (_companionEnabled == enabled) return;
    _companionEnabled = enabled;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionEnabled: enabled,
    );
    await _settingsRepo.save(updated);

    if (enabled && Platform.isMacOS) {
      await _syncToNativeSpawn();
    } else if (Platform.isMacOS) {
      await MacOSBridge.hideCompanion();
    }
    notifyListeners();
  }

  /// Dynamic updater for switching cat themes.
  Future<void> changeTheme(String themeId) async {
    if (_companionCatTheme == themeId) return;
    _companionCatTheme = themeId;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionCatTheme: themeId,
    );
    await _settingsRepo.save(updated);

    if (_companionEnabled && Platform.isMacOS) {
      await MacOSBridge.updateCompanionTheme(themeId);
    }

    // Dynamically update the status bar tray icons matching the selected breed
    try {
      await sl<TrayManagerService>().updateSelectedBreed(themeId);
    } catch (_) {}

    notifyListeners();
  }

  Future<void> changePetName(String petName) async {
    final trimmedName = petName.trim();
    final nextName = trimmedName.isEmpty ? 'Mochi' : trimmedName;
    if (_companionPetName == nextName) return;
    _companionPetName = nextName;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionPetName: nextName,
    );
    await _settingsRepo.save(updated);

    if (_companionEnabled && Platform.isMacOS) {
      await MacOSBridge.updateCompanionName(nextName);
    }

    notifyListeners();
  }

  /// Dynamic updater for altering window dimensions & pixel scaling.
  Future<void> changeScale(double scale) async {
    if (_companionScale == scale) return;
    _companionScale = scale;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionScale: scale,
    );
    await _settingsRepo.save(updated);

    if (_companionEnabled && Platform.isMacOS) {
      await MacOSBridge.updateCompanionScale(scale);
    }
    notifyListeners();
  }

  /// Toggles click-through mode natively.
  Future<void> changeClickThrough(bool enabled) async {
    if (_companionClickThrough == enabled) return;
    _companionClickThrough = enabled;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionClickThrough: enabled,
    );
    await _settingsRepo.save(updated);

    if (_companionEnabled && Platform.isMacOS) {
      await MacOSBridge.setCompanionClickThrough(enabled);
    }
    notifyListeners();
  }

  /// Forces an immediate full sync of all companion settings to the native window.
  /// Use this when changes aren't rendering instantly — sends everything in one shot.
  Future<void> refreshCompanion() async {
    if (!_companionEnabled || !Platform.isMacOS) return;

    // Hide and re-spawn for a clean render
    await MacOSBridge.hideCompanion();
    // Small delay to ensure the window is fully torn down
    await Future.delayed(const Duration(milliseconds: 300));
    await _syncToNativeSpawn();
  }
}
