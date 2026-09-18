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
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/errors/error_handler.dart';

class CompanionOverlayController extends ChangeNotifier {
  final SettingsRepository _settingsRepo;

  List<PetProfile> get availablePets =>
      sl<PetRegistryService>().getEnabledProfiles();

  bool _isTransitioning = false;
  bool _companionEnabled = false;
  bool _pipModeEnabled = false;
  String _companionPetTheme = 'grey_cat';
  String _companionPetName = 'Mochi';
  double _companionScale = 6.0;
  bool _companionClickThrough = false;
  bool _companionFollowMouse = false;
  bool _enableAnimations = true;
  String _companionPreviewBackground =
      ''; // asset-migration: background assets removed
  bool _isCompanionShown = false;
  bool _isPreviewMode =
      false; // Hides native companion when viewing settings UI

  String _pipBackgroundStyle = 'dark';
  double _pipOpacity = 1.0;
  bool _pipDraggableClickable = true;
  String _companionToyType = 'tennis_ball';
  String _companionTreatType = 'sushi';

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

  static const List<String> flamingoNames = [
    'Pinky',
    'Flo',
    'Mingo',
    'Ruby',
    'Peach',
    'Mango',
    'Sherbet',
    'Flammie',
    'Coral',
    'Sunset',
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
    // We do not show the companion automatically on timer/break transitions
    // if the user has explicitly closed it.
  }

  bool get isTransitioning => _isTransitioning;
  bool get companionEnabled => _companionEnabled;
  bool get pipModeEnabled => _pipModeEnabled;
  String get companionPetTheme => _companionPetTheme;
  String get companionPetName => _companionPetName;
  double get companionScale => _companionScale;
  bool get companionClickThrough => _companionClickThrough;
  bool get companionFollowMouse => _companionFollowMouse;
  String get pipBackgroundStyle => _pipBackgroundStyle;
  double get pipOpacity => _pipOpacity;
  bool get pipDraggableClickable => _pipDraggableClickable;
  String get companionToyType => _companionToyType;
  String get companionTreatType => _companionTreatType;
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
    _pipBackgroundStyle = settings.pipBackgroundStyle;
    _pipOpacity = settings.pipOpacity;
    _pipDraggableClickable = settings.pipDraggableClickable;
    _companionToyType = settings.companionToyType;
    _companionTreatType = settings.companionTreatType;

    try {
      _isBreakActive = sl<TimerEngine>().state == TimerState.breakActive;
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    final shouldShow = _companionEnabled && settings.hasCompletedOnboarding;
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
    final pipBackgroundStyleChanged =
        _pipBackgroundStyle != settings.pipBackgroundStyle;
    final pipOpacityChanged = _pipOpacity != settings.pipOpacity;
    final pipDraggableClickableChanged =
        _pipDraggableClickable != settings.pipDraggableClickable;
    final toyTypeChanged = _companionToyType != settings.companionToyType;
    final treatTypeChanged = _companionTreatType != settings.companionTreatType;

    if (!enabledChanged &&
        !pipModeChanged &&
        !themeChanged &&
        !nameChanged &&
        !scaleChanged &&
        !clickChanged &&
        !followChanged &&
        !animationsChanged &&
        !backgroundChanged &&
        !pipBackgroundStyleChanged &&
        !pipOpacityChanged &&
        !pipDraggableClickableChanged &&
        !toyTypeChanged &&
        !treatTypeChanged) {
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
    _pipBackgroundStyle = settings.pipBackgroundStyle;
    _pipOpacity = settings.pipOpacity;
    _pipDraggableClickable = settings.pipDraggableClickable;
    _companionToyType = settings.companionToyType;
    _companionTreatType = settings.companionTreatType;

    final shouldShow =
        _companionEnabled &&
        settings.hasCompletedOnboarding &&
        (!_isPreviewMode || _pipModeEnabled);

    final needsShowOrToggle =
        shouldShow && (!_isCompanionShown || pipModeChanged);
    final needsHide = !shouldShow && _isCompanionShown;

    if (needsShowOrToggle || needsHide) {
      debugPrint(
        '[CompanionOverlayController] Starting transition... needsShowOrToggle: $needsShowOrToggle, needsHide: $needsHide',
      );
      _isTransitioning = true;
      notifyListeners();

      // Create a safety timeout timer in case a native call hangs indefinitely.
      // This is a workaround for platform window-spawning MethodChannels that could block
      // indefinitely if the native window manager fails to complete high-priority window actions.
      final safetyTimer = Timer(const Duration(seconds: 3), () {
        if (_isTransitioning) {
          debugPrint(
            '[CompanionOverlayController] WARNING: Transition safety timeout hit! Forcing loader dismissal.',
          );
          _isTransitioning = false;
          notifyListeners();
        }
      });

      Future.microtask(() async {
        // Yield control to let Flutter render the loading overlay frame
        await Future.delayed(const Duration(milliseconds: 80));
        try {
          if (needsShowOrToggle) {
            if (_isCompanionShown && pipModeChanged) {
              _isCompanionShown = false;
              debugPrint(
                '[CompanionOverlayController] Toggling modes, hiding current companion window...',
              );
              await NativeBridge.hideCompanion();
              await NativeBridge.hidePipWindow();
              await Future.delayed(const Duration(milliseconds: 300));
            }
            debugPrint(
              '[CompanionOverlayController] Spawning new companion/PiP window...',
            );
            await _showNativeCompanion();
          } else if (needsHide) {
            _isCompanionShown = false;
            debugPrint(
              '[CompanionOverlayController] Hiding companion/PiP window...',
            );
            await NativeBridge.hideCompanion();
            await NativeBridge.hidePipWindow();
          }
          debugPrint(
            '[CompanionOverlayController] Transition completed successfully.',
          );
        } catch (e, st) {
          debugPrint(
            '[CompanionOverlayController] Transition failed with error: $e',
          );
          ErrorHandler().handleError(e, st);
        } finally {
          safetyTimer.cancel();
          _isTransitioning = false;
          notifyListeners();
        }
      });
    } else {
      if (shouldShow) {
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
        if (animationsChanged ||
            backgroundChanged ||
            pipBackgroundStyleChanged ||
            pipOpacityChanged ||
            pipDraggableClickableChanged ||
            toyTypeChanged ||
            treatTypeChanged) {
          if (_pipModeEnabled) {
            NativeBridge.showPipWindow(
              PipWindowArgs.fromMap(_companionPayload()),
            );
          } else {
            NativeBridge.showCompanion(CompanionArgs(_companionPayload()));
          }
        }
      }
    }

    notifyListeners(); // Keep the Flutter UI completely in sync!
  }

  Future<void> _showNativeCompanion() async {
    if (_isCompanionShown) return;
    if (_isPreviewMode && !_pipModeEnabled) return;

    _isCompanionShown = true;
    if (_pipModeEnabled) {
      await NativeBridge.showPipWindow(
        PipWindowArgs.fromMap(_companionPayload()),
      );
    } else {
      await NativeBridge.showCompanion(CompanionArgs(_companionPayload()));
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
      'pipBackgroundStyle': _pipBackgroundStyle,
      'pipOpacity': _pipOpacity,
      'pipDraggableClickable': _pipDraggableClickable,
      'companionToyType': _companionToyType,
      'companionTreatType': _companionTreatType,
      'previewBackground': _companionPreviewBackground,
    };
  }

  void setPreviewMode(bool isPreview) {
    if (_isPreviewMode == isPreview) return;
    _isPreviewMode = isPreview;

    if (_isPreviewMode) {
      if (!_pipModeEnabled) {
        if (_isCompanionShown) {
          _isCompanionShown = false;
          NativeBridge.hideCompanion();
          NativeBridge.hidePipWindow();
        }
      }
    } else {
      final settings = _settingsRepo.currentSettings;
      final shouldShow = _companionEnabled && settings.hasCompletedOnboarding;
      if (shouldShow && !_isCompanionShown) {
        _showNativeCompanion();
      }
    }
    notifyListeners();
  }

  Future<void> toggleCompanion(bool enabled) async {
    if (_companionEnabled == enabled || _isTransitioning) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionEnabled: enabled,
      pipModeEnabled: enabled
          ? _settingsRepo.currentSettings.pipModeEnabled
          : false,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeTheme(String themeId) async {
    if (_companionPetTheme == themeId || _isTransitioning) return;

    // Evict existing pet assets and clear cached SpriteSheets to release memory before loading the new theme.
    // This prevents GPU memory overhead from accumulative sprite sheets when the breed is toggled.
    PetAssetLoader.clearCache();
    Flame.images.clear(themeId);

    final species = PetTheme.getTheme(themeId).species;
    final random = Random();
    final List<String> names;

    if (species == PetSpecies.dog) {
      names = dogNames;
    } else if (species == PetSpecies.flamingo) {
      names = flamingoNames;
    } else {
      names = catNames;
    }

    String randomName = _companionPetName;
    if (names.length > 1) {
      do {
        randomName = names[random.nextInt(names.length)];
      } while (randomName == _companionPetName);
    } else if (names.isNotEmpty) {
      randomName = names.first;
    }

    final updated = _settingsRepo.currentSettings.copyWith(
      companionPetTheme: themeId,
      companionPetName: randomName,
    );
    await _settingsRepo.save(updated);

    int retries = 0;
    while (retries < 3) {
      try {
        await sl<TrayManagerService>().updateSelectedBreed(themeId);
        break;
      } catch (e, st) {
        retries++;
        if (retries >= 3) {
          ErrorHandler().handleError(
            AppException(
              type: AppErrorType.ui,
              message:
                  'Failed to update selected breed after 3 attempts: ${e.toString()}',
              originalError: e,
              stackTrace: st,
            ),
            st,
          );
        } else {
          await Future.delayed(Duration(milliseconds: 500 * retries));
        }
      }
    }
  }

  Future<void> changePetName(String petName) async {
    final trimmedName = petName.trim();
    final nextName = trimmedName.isEmpty ? 'Mochi' : trimmedName;
    if (_companionPetName == nextName || _isTransitioning) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionPetName: nextName,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeScale(double scale) async {
    if (_companionScale == scale || _isTransitioning) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionScale: scale,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeClickThrough(bool enabled) async {
    if (_companionClickThrough == enabled || _isTransitioning) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionClickThrough: enabled,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeFollowMouse(bool enabled) async {
    if (_companionFollowMouse == enabled || _isTransitioning) return;

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
    if (_pipModeEnabled == value || _isTransitioning) return;
    if (value && !_companionEnabled) return;
    final updated = _settingsRepo.currentSettings.copyWith(
      pipModeEnabled: value,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changePipBackgroundStyle(String style) async {
    if (_pipBackgroundStyle == style) return;
    final updated = _settingsRepo.currentSettings.copyWith(
      pipBackgroundStyle: style,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changePipOpacity(double opacity) async {
    if (_pipOpacity == opacity) return;
    final updated = _settingsRepo.currentSettings.copyWith(pipOpacity: opacity);
    await _settingsRepo.save(updated);
  }

  Future<void> changePipDraggableClickable(bool enabled) async {
    if (_pipDraggableClickable == enabled) return;
    final updated = _settingsRepo.currentSettings.copyWith(
      pipDraggableClickable: enabled,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeToyType(String toyType) async {
    if (_companionToyType == toyType) return;
    final updated = _settingsRepo.currentSettings.copyWith(
      companionToyType: toyType,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> changeTreatType(String treatType) async {
    if (_companionTreatType == treatType) return;
    final updated = _settingsRepo.currentSettings.copyWith(
      companionTreatType: treatType,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> refreshCompanion() async {
    if (!_companionEnabled || _isTransitioning) return;
    _isTransitioning = true;
    notifyListeners();

    final safetyTimer = Timer(const Duration(seconds: 3), () {
      if (_isTransitioning) {
        debugPrint(
          '[CompanionOverlayController] WARNING: Refresh safety timeout hit! Forcing loader dismissal.',
        );
        _isTransitioning = false;
        notifyListeners();
      }
    });

    await Future.delayed(const Duration(milliseconds: 80));
    try {
      _isCompanionShown = false;
      await NativeBridge.hideCompanion();
      await NativeBridge.hidePipWindow();
      await Future.delayed(const Duration(milliseconds: 300));
      await _showNativeCompanion();
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    } finally {
      safetyTimer.cancel();
      _isTransitioning = false;
      notifyListeners();
    }
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
