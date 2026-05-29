import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/companion/services/companion_behavior_engine.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:flame/flame.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/services/timer_engine.dart';

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
      : _settingsRepo = settingsRepo {
    _settingsRepo.addListener(_handleSettingsChanged);
    _listenToEvents();
  }

  bool _isBreakActive = false;
  StreamSubscription<AppEvent>? _eventSub;

  void _listenToEvents() {
    _eventSub = sl<EventBus>().stream.listen((event) {
      if (event is TimerStateChangedEvent) {
        _handleTimerStateChanged(event);
      }
    });
  }

  void _handleTimerStateChanged(TimerStateChangedEvent event) {
    final isBreak = event.state == TimerStateEvent.breakActive;
    if (_isBreakActive == isBreak) return;
    _isBreakActive = isBreak;

    if (!_companionEnabled) return;

    if (isBreak) {
      NativeBridge.hideCompanion();
    } else {
      _showNativeCompanion();
    }
  }

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

    // Check initial break state if possible, though TimerEngine usually starts later
    try {
      _isBreakActive = sl<TimerEngine>().state == TimerState.breakActive;
    } catch (_) {}

    if (_companionEnabled && !_isBreakActive) {
      unawaited(_showNativeCompanion());
    }
  }

  void _handleSettingsChanged() {
    final settings = _settingsRepo.currentSettings;

    final oldEnabled = _companionEnabled;
    final themeChanged = _companionPetTheme != settings.companionPetTheme;
    final nameChanged = _companionPetName != settings.companionPetName;
    final scaleChanged = _companionScale != settings.companionScale;
    final clickChanged =
        _companionClickThrough != settings.companionClickThrough;
    final followChanged = _companionFollowMouse != settings.companionFollowMouse;

    _companionEnabled = settings.companionEnabled;
    _companionPetTheme = settings.companionPetTheme;
    _companionPetName = settings.companionPetName;
    _companionScale = settings.companionScale;
    _companionClickThrough = settings.companionClickThrough;
    _companionFollowMouse = settings.companionFollowMouse;

    // Check if enabled state changed
    if (oldEnabled != _companionEnabled) {
      if (_companionEnabled && !_isBreakActive) {
        _showNativeCompanion();
      } else {
        NativeBridge.hideCompanion();
      }

      try {
        sl<CompanionBehaviorEngine>().setEnabled(_companionEnabled);
      } catch (_) {}

      notifyListeners();
      return; // If enabled state changed, we don't need to check individual params here as _showNativeCompanion handles them
    }

    // Check if other settings changed and we are enabled and not in a break
    if (_companionEnabled && !_isBreakActive) {
      if (themeChanged) {
        NativeBridge.updateCompanionTheme(_companionPetTheme);
        notifyListeners();
      }
      if (nameChanged) {
        NativeBridge.updateCompanionName(_companionPetName);
        notifyListeners();
      }
      if (scaleChanged) {
        NativeBridge.updateCompanionScale(_companionScale);
        notifyListeners();
      }
      if (clickChanged) {
        NativeBridge.setCompanionClickThrough(_companionClickThrough);
        notifyListeners();
      }
      if (followChanged) {
        NativeBridge.setCompanionFollowMouse(_companionFollowMouse);
        notifyListeners();
      }
    }
  }

  /// Shows the companion via the native bridge (works on macOS + Windows).
  Future<void> _showNativeCompanion() async {
    await NativeBridge.showCompanion({
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

    // Just update settings, _handleSettingsChanged will handle the rest
    final updated = _settingsRepo.currentSettings.copyWith(
      companionEnabled: enabled,
    );
    await _settingsRepo.save(updated);
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
    
    // Update settings, listener will handle native updates
    final updated = _settingsRepo.currentSettings.copyWith(
      companionPetTheme: themeId,
      companionPetName: randomName,
    );
    await _settingsRepo.save(updated);

    try {
      await sl<TrayManagerService>().updateSelectedBreed(themeId);
    } catch (_) {}
  }

  Future<void> changePetName(String petName) async {
    final trimmedName = petName.trim();
    final nextName = trimmedName.isEmpty ? 'Mochi' : trimmedName;
    if (_companionPetName == nextName) return;
    
    final updated = _settingsRepo.currentSettings.copyWith(
      companionPetName: nextName,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeScale(double scale) async {
    if (_companionScale == scale) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionScale: scale,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeClickThrough(bool enabled) async {
    if (_companionClickThrough == enabled) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionClickThrough: enabled,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeFollowMouse(bool enabled) async {
    if (_companionFollowMouse == enabled) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionFollowMouse: enabled,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> refreshCompanion() async {
    if (!_companionEnabled) return;
    await NativeBridge.hideCompanion();
    await Future.delayed(const Duration(milliseconds: 300));
    await _showNativeCompanion();
  }

  @override
  void dispose() {
    _settingsRepo.removeListener(_handleSettingsChanged);
    _eventSub?.cancel();
    if (_companionEnabled) {
      NativeBridge.hideCompanion();
    }
    super.dispose();
  }
}
