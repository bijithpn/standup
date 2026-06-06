import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:flame/flame.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/services/timer_engine.dart';

import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/services/pet_registry_service.dart';

/// Controls the desktop companion pet window.
class CompanionOverlayController extends ChangeNotifier {
  final SettingsRepository _settingsRepo;

  List<PetProfile> get availablePets =>
      sl<PetRegistryService>().getEnabledProfiles();

  bool _companionEnabled = false;
  bool _pipModeEnabled = false;
  String _companionPetTheme = 'grey_cat';
  String _companionPetName = 'Mochi';
  double _companionScale = 6.0;
  bool _companionClickThrough = false;
  bool _companionFollowMouse = false;
  bool _enableAnimations = true;
  String _companionPreviewBackground =
      'assets/background/forest/background.png';
  bool _isCompanionShown = false;
  bool _isPreviewMode =
      false; // Hides native companion when viewing settings UI

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
  bool get pipModeEnabled => _pipModeEnabled;
  String get companionPetTheme => _companionPetTheme;
  String get companionPetName => _companionPetName;
  double get companionScale => _companionScale;
  bool get companionClickThrough => _companionClickThrough;
  bool get companionFollowMouse => _companionFollowMouse;
  bool get pettingEnabled => _settingsRepo.currentSettings.pettingEnabled;
  bool get ballThrowEnabled => _settingsRepo.currentSettings.ballThrowEnabled;
  bool get treatEnabled => _settingsRepo.currentSettings.treatEnabled;
  bool get developerReactions =>
      _settingsRepo.currentSettings.developerReactions;
  bool get quietModeAutoActivate =>
      _settingsRepo.currentSettings.quietModeAutoActivate;
  bool get isLowDistractionMode =>
      _companionClickThrough && !_companionFollowMouse && !_enableAnimations;
  String get companionStateExplanation {
    if (!_companionEnabled) {
      return 'Companion is disabled in settings.';
    }
    if (_isBreakActive) {
      return 'Companion is hidden while a break overlay is active.';
    }
    if (isLowDistractionMode) {
      return 'Companion is quiet, click-through, and throttled for focus.';
    }
    if (_companionFollowMouse) {
      return 'Companion is actively following your cursor.';
    }
    if (_companionClickThrough) {
      return 'Companion is visible but ignoring mouse input.';
    }
    return 'Companion is active and available for interaction.';
  }

  String get companionPreviewBackground => _companionPreviewBackground;

  Future<void> init() async {
    final settings = _settingsRepo.currentSettings;

    _companionEnabled = settings.companionEnabled;
    _pipModeEnabled = settings.pipModeEnabled;
    _companionPetTheme = settings.companionPetTheme;
    _companionPetName = settings.companionPetName;
    _companionScale = settings.companionScale;
    _companionClickThrough = settings.companionClickThrough;
    _companionFollowMouse = settings.companionFollowMouse;
    _enableAnimations = settings.enableAnimations;
    _companionPreviewBackground = settings.companionPreviewBackground;

    // Check initial break state if possible, though TimerEngine usually starts later
    try {
      _isBreakActive = sl<TimerEngine>().state == TimerState.breakActive;
    } catch (_) {}

    final shouldShow =
        _companionEnabled && !_isBreakActive && settings.hasCompletedOnboarding;
    if (shouldShow) {
      unawaited(_showNativeCompanion());
    }
  }

  void _handleSettingsChanged() {
    final settings = _settingsRepo.currentSettings;

    final enabledChanged = _companionEnabled != settings.companionEnabled;
    final pipModeChanged = _pipModeEnabled != settings.pipModeEnabled;
    final themeChanged = _companionPetTheme != settings.companionPetTheme;
    final nameChanged = _companionPetName != settings.companionPetName;
    final scaleChanged = _companionScale != settings.companionScale;
    final clickChanged =
        _companionClickThrough != settings.companionClickThrough;
    final followChanged =
        _companionFollowMouse != settings.companionFollowMouse;
    final animationsChanged = _enableAnimations != settings.enableAnimations;
    final backgroundChanged =
        _companionPreviewBackground != settings.companionPreviewBackground;

    if (!enabledChanged &&
        !pipModeChanged &&
        !themeChanged &&
        !nameChanged &&
        !scaleChanged &&
        !clickChanged &&
        !followChanged &&
        !animationsChanged &&
        !backgroundChanged) {
      return; // Exit early if no companion settings have changed
    }

    _companionEnabled = settings.companionEnabled;
    _pipModeEnabled = settings.pipModeEnabled;
    _companionPetTheme = settings.companionPetTheme;
    _companionPetName = settings.companionPetName;
    _companionScale = settings.companionScale;
    _companionClickThrough = settings.companionClickThrough;
    _companionFollowMouse = settings.companionFollowMouse;
    _enableAnimations = settings.enableAnimations;
    _companionPreviewBackground = settings.companionPreviewBackground;

    final shouldShow =
        _companionEnabled &&
        !_isBreakActive &&
        settings.hasCompletedOnboarding &&
        !_isPreviewMode;

    if (shouldShow) {
      if (!_isCompanionShown || pipModeChanged) {
        if (_isCompanionShown && pipModeChanged) {
          _isCompanionShown = false;
          NativeBridge.hideCompanion();
          NativeBridge.hidePipWindow();
        }
        _showNativeCompanion();
      } else {
        if (themeChanged) {
          NativeBridge.updateCompanionTheme(_companionPetTheme);
        }
        if (nameChanged) {
          NativeBridge.updateCompanionName(_companionPetName);
        }
        if (scaleChanged) {
          NativeBridge.updateCompanionScale(_companionScale);
        }
        if (clickChanged) {
          NativeBridge.setCompanionClickThrough(_companionClickThrough);
        }
        if (followChanged) {
          NativeBridge.setCompanionFollowMouse(_companionFollowMouse);
        }
        if (animationsChanged) {
          if (_pipModeEnabled) {
            NativeBridge.showPipWindow(_companionPayload());
          } else {
            NativeBridge.showCompanion(_companionPayload());
          }
        }
      }
    } else {
      if (_isCompanionShown) {
        _isCompanionShown = false;
        NativeBridge.hideCompanion();
        NativeBridge.hidePipWindow();
      }
    }

    notifyListeners(); // Keep the Flutter UI completely in sync!
  }

  Future<void> _showNativeCompanion() async {
    if (_isCompanionShown) return;
    if (_isPreviewMode) return;

    _isCompanionShown = true;
    if (_pipModeEnabled) {
      await NativeBridge.showPipWindow(_companionPayload());
    } else {
      await NativeBridge.showCompanion(_companionPayload());
    }
  }

  Map<String, dynamic> _companionPayload() {
    return {
      'themeId': _companionPetTheme,
      'petName': _companionPetName,
      'scale': _companionScale,
      'clickThrough': _companionClickThrough,
      'followMouse': _companionFollowMouse,
      'wanderingEnabled': _enableAnimations,
      'isLowPowerMode': !_enableAnimations,
    };
  }

  /// Toggles preview mode. When true, the native companion is hidden.
  void setPreviewMode(bool isPreview) {
    if (_isPreviewMode == isPreview) return;
    _isPreviewMode = isPreview;

    if (_isPreviewMode) {
      if (_isCompanionShown) {
        _isCompanionShown = false;
        NativeBridge.hideCompanion();
      }
    } else {
      final settings = _settingsRepo.currentSettings;
      final shouldShow =
          _companionEnabled &&
          !_isBreakActive &&
          settings.hasCompletedOnboarding;
      if (shouldShow && !_isCompanionShown) {
        _showNativeCompanion();
      }
    }
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

    final species = PetTheme.getTheme(themeId).species;
    final random = Random();
    final List<String> names;

    if (species == PetSpecies.dog) {
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

  Future<void> setLowDistractionMode(bool enabled) async {
    final current = _settingsRepo.currentSettings;
    final updated = current.copyWith(
      companionClickThrough: enabled ? true : current.companionClickThrough,
      companionFollowMouse: enabled ? false : current.companionFollowMouse,
      enableAnimations: enabled ? false : true,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changePreviewBackground(String path) async {
    if (_companionPreviewBackground == path) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionPreviewBackground: path,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changePettingEnabled(bool value) async {
    final updated = _settingsRepo.currentSettings.copyWith(
      pettingEnabled: value,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeBallThrowEnabled(bool value) async {
    final updated = _settingsRepo.currentSettings.copyWith(
      ballThrowEnabled: value,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeTreatEnabled(bool value) async {
    final updated = _settingsRepo.currentSettings.copyWith(treatEnabled: value);
    await _settingsRepo.save(updated);
  }

  Future<void> changeDeveloperReactions(bool value) async {
    final updated = _settingsRepo.currentSettings.copyWith(
      developerReactions: value,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeQuietModeAutoActivate(bool value) async {
    final updated = _settingsRepo.currentSettings.copyWith(
      quietModeAutoActivate: value,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changePipModeEnabled(bool value) async {
    if (_pipModeEnabled == value) return;
    final updated = _settingsRepo.currentSettings.copyWith(
      pipModeEnabled: value,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> refreshCompanion() async {
    if (!_companionEnabled) return;
    _isCompanionShown = false;
    await NativeBridge.hideCompanion();
    await NativeBridge.hidePipWindow();
    await Future.delayed(const Duration(milliseconds: 300));
    await _showNativeCompanion();
  }

  @override
  void dispose() {
    _settingsRepo.removeListener(_handleSettingsChanged);
    _eventSub?.cancel();
    if (_companionEnabled) {
      _isCompanionShown = false;
      NativeBridge.hideCompanion();
      NativeBridge.hidePipWindow();
    }
    super.dispose();
  }
}
