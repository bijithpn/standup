import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/macos_bridge.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/companion/services/companion_behavior_engine.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:flame/flame.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';

/// Controls the desktop companion pet window.
class CompanionOverlayController extends ChangeNotifier {
  final SettingsRepository _settingsRepo;

  bool _companionEnabled = false;
  String _companionPetTheme = 'grey_cat';
  String _companionPetName = 'Mochi';
  double _companionScale = 6.0;
  bool _companionClickThrough = false;
  bool _companionFollowMouse = false;

  static const List<String> catNames = [
    'Mochi',
    'Luna',
    'Milo',
    'Bella',
    'Oliver',
    'Simba',
    'Chloe',
    'Cleo',
    'Loki',
    'Lily',
    'Oreo',
    'Nala',
    'Coco',
    'Ziggy',
    'Biscuit',
    'Peanut',
    'Pumpkin',
    'Mocha',
    'Pip',
    'Mimi',
    'Cookie',
    'Teddy',
    'Penny',
    'Ruby',
    'Lucky',
  ];

  static const List<String> dogNames = [
    'Buster',
    'Buddy',
    'Max',
    'Daisy',
    'Charlie',
    'Cooper',
    'Lola',
    'Bailey',
    'Teddy',
    'Sadie',
    'Rocky',
    'Tucker',
    'Bear',
    'Bentley',
    'Toby',
    'Winston',
    'Rosie',
    'Bella',
    'Oliver',
    'Coco',
    'Duke',
    'Jax',
    'Milo',
    'Ruby',
    'Harley',
  ];

  static const List<String> rabbitNames = [
    'Cottontail',
    'Thumper',
    'Bunny',
    'Bugs',
    'Snowball',
    'Peter',
    'Hops',
    'Flop',
  ];

  static const List<String> foxNames = [
    'Rusty',
    'Foxy',
    'Vixen',
    'Todd',
    'Sly',
    'Firefox',
    'Red',
    'Nick',
  ];

  static const List<String> dragonNames = [
    'Spyro',
    'Toothless',
    'Smaug',
    'Draco',
    'Norbert',
    'Bahamut',
    'Ember',
    'Ignis',
  ];

  CompanionOverlayController({required SettingsRepository settingsRepo})
    : _settingsRepo = settingsRepo;

  bool get companionEnabled => _companionEnabled;
  String get companionPetTheme => _companionPetTheme;
  String get companionPetName => _companionPetName;
  double get companionScale => _companionScale;
  bool get companionClickThrough => _companionClickThrough;
  bool get companionFollowMouse => _companionFollowMouse;

  Future<void> init() async {
    final settings = _settingsRepo.currentSettings;

    _companionEnabled = settings.companionEnabled;
    _companionPetTheme = settings.companionPetTheme;
    _companionPetName = settings.companionPetName;
    _companionScale = settings.companionScale;
    _companionClickThrough = settings.companionClickThrough;
    _companionFollowMouse = settings.companionFollowMouse;

    if (_companionEnabled) {
      await _showNativeCompanion();
    }
  }

  /// Shows the companion via the native bridge (works on macOS + Windows).
  Future<void> _showNativeCompanion() async {
    await MacOSBridge.showCompanion({
      'themeId': _companionPetTheme,
      'petName': _companionPetName,
      'scale': _companionScale,
      'clickThrough': _companionClickThrough,
      'followMouse': _companionFollowMouse,
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

    try {
      sl<CompanionBehaviorEngine>().setEnabled(enabled);
    } catch (_) {}

    if (enabled) {
      await _showNativeCompanion();
    } else {
      await MacOSBridge.hideCompanion();
    }
    notifyListeners();
  }

  /// Dynamic updater for switching companion themes.
  Future<void> changeTheme(String themeId) async {
    if (_companionPetTheme == themeId) return;

    // Evict old pet theme assets aggressively from main isolate
    PetAssetLoader.clearCache();
    Flame.images.clear(themeId);

    _companionPetTheme = themeId;

    final species = PetTheme.getTheme(themeId).species;
    final random = Random();
    final List<String> names;

    if (species == PetSpecies.rabbit) {
      names = rabbitNames;
    } else if (species == PetSpecies.fox) {
      names = foxNames;
    } else if (species == PetSpecies.dragon) {
      names = dragonNames;
    } else if (species == PetSpecies.dog) {
      names = dogNames;
    } else {
      names = catNames;
    }

    final randomName = names[random.nextInt(names.length)];
    _companionPetName = randomName;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionPetTheme: themeId,
      companionPetName: randomName,
    );
    await _settingsRepo.save(updated);

    if (_companionEnabled) {
      await MacOSBridge.updateCompanionTheme(themeId);
      await MacOSBridge.updateCompanionName(randomName);
    }

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

    if (_companionEnabled) {
      await MacOSBridge.updateCompanionName(nextName);
    }

    notifyListeners();
  }

  Future<void> changeScale(double scale) async {
    if (_companionScale == scale) return;
    _companionScale = scale;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionScale: scale,
    );
    await _settingsRepo.save(updated);

    if (_companionEnabled) {
      await MacOSBridge.updateCompanionScale(scale);
    }
    notifyListeners();
  }

  Future<void> changeClickThrough(bool enabled) async {
    if (_companionClickThrough == enabled) return;
    _companionClickThrough = enabled;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionClickThrough: enabled,
    );
    await _settingsRepo.save(updated);

    if (_companionEnabled) {
      await MacOSBridge.setCompanionClickThrough(enabled);
    }
    notifyListeners();
  }

  Future<void> changeFollowMouse(bool enabled) async {
    if (_companionFollowMouse == enabled) return;
    _companionFollowMouse = enabled;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionFollowMouse: enabled,
    );
    await _settingsRepo.save(updated);

    if (_companionEnabled) {
      await MacOSBridge.setCompanionFollowMouse(enabled);
    }
    notifyListeners();
  }

  Future<void> refreshCompanion() async {
    if (!_companionEnabled) return;
    await MacOSBridge.hideCompanion();
    await Future.delayed(const Duration(milliseconds: 300));
    await _showNativeCompanion();
  }

  @override
  void dispose() {
    if (_companionEnabled) {
      MacOSBridge.hideCompanion();
    }
    super.dispose();
  }
}
