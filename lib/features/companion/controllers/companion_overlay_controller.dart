import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/services/timer_engine.dart';

import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/services/pet_registry_service.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';

part 'companion_overlay_setting_actions.dart';

class CompanionOverlayController extends ChangeNotifier {
  final SettingsRepository _settingsRepo;

  /// Increments whenever an external surface (such as the PiP window) requests
  /// opening the Blobatar rename dialog in the main app.
  final ValueNotifier<int> openBlobatarNameDialogNotifier = ValueNotifier<int>(
    0,
  );
  bool _pendingBlobatarNameDialogRequest = false;

  void requestOpenBlobatarNameDialog() {
    _pendingBlobatarNameDialogRequest = true;
    openBlobatarNameDialogNotifier.value++;
  }

  bool consumePendingBlobatarNameDialogRequest() {
    if (_pendingBlobatarNameDialogRequest) {
      _pendingBlobatarNameDialogRequest = false;
      return true;
    }
    return false;
  }

  List<PetProfile> get availablePets =>
      sl<PetRegistryService>().getEnabledProfiles();

  bool _isTransitioning = false;
  bool _companionEnabled = false;
  bool _pipModeEnabled = true;
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

  String _pipBackgroundStyle = 'transparent';
  double _pipOpacity = 1.0;
  bool _pipDraggableClickable = true;
  String _companionToyType = 'tennis_ball';
  String _companionTreatType = 'sushi';

  /// The companion's saved appearance, as JSON-encoded `AvatarDefinition`.
  /// Null until the customizer has produced one.
  String? _companionAvatarDefinition;

  /// Whether the companion stays out all the time, or only during breaks.
  bool _companionKeepOnScreen = true;

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

  static const List<String> blobatarNames = [
    'Bubbles',
    'Mochi',
    'Cosmo',
    'Ziggy',
    'Pebble',
    'Pixel',
    'Noodle',
    'Pip',
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
      } else if (event is BreakEndedEvent) {
        _handleBreakEnded(event);
      } else if (event is CompanionInteractionEvent) {
        _handleCompanionInteraction(event);
      }
    });
  }

  /// Interactions relayed from the overlay window, which runs in its own
  /// engine and cannot write settings itself.
  void _handleCompanionInteraction(CompanionInteractionEvent event) {
    switch (event.interactionType) {
      case 'openBlobatarEditor':
        if (sl.isRegistered<OverlayWindowService>()) {
          unawaited(sl<OverlayWindowService>().showDashboard(forceShow: true));
        }
        if (sl.isRegistered<AppNavigationService>()) {
          sl<AppNavigationService>().openSection('Companion');
        }
        requestOpenBlobatarNameDialog();
      case 'rename':
        final name = event.metadata?['petName']?.toString().trim();
        if (name == null || name.isEmpty) return;
        unawaited(changePetName(name));
      case 'pipReady':
        final ready = _pipReady;
        if (ready != null && !ready.isCompleted) ready.complete();
      case 'closeCompanion':
        // The window's own close button. Treated as turning the companion off,
        // so the switch in Settings matches and can bring it back.
        unawaited(toggleCompanion(false));
      case 'keepOnScreen':
        final value = event.metadata?['value'];
        if (value is bool) unawaited(changeKeepOnScreen(value));
      case 'takeBreak':
        // The companion asks for this when it has watched the user work for a
        // long unbroken stretch. It is the one interaction that is not really
        // about the pet.
        if (sl.isRegistered<TimerEngine>()) {
          sl<TimerEngine>().triggerBreakNow();
        }
    }
  }

  /// Chooses whether the companion stays out all the time, or only shows up
  /// while a break is running.
  Future<void> changeKeepOnScreen(bool keepOnScreen) async {
    if (_companionKeepOnScreen == keepOnScreen) return;
    await _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(
        companionKeepOnScreen: keepOnScreen,
      ),
    );
  }

  void _handleTimerStateChanged(TimerStateChangedEvent event) {
    final isBreak = event.state == TimerStateEvent.breakActive;
    if (_isBreakActive == isBreak) return;
    _isBreakActive = isBreak;
    _applyBreakVisibility();
    // A gentle nudge as a break begins. Only the companion's face changes; no
    // sound, notification or window activation is involved.
    if (isBreak) _notifyCompanion('breakReminder');
  }

  /// A finished break is the one thing the companion celebrates. Skipped
  /// breaks are not worth a reaction either way.
  void _handleBreakEnded(BreakEndedEvent event) {
    if (event.skipped) return;
    _notifyCompanion('breakCompleted');
  }

  /// Tells the floating companion about something that happened, if it is
  /// showing and the user has reactions switched on. The companion applies its
  /// own rules too; this just avoids a native round-trip nobody will see.
  void _notifyCompanion(String eventName) {
    if (!_companionEnabled || !_isCompanionShown || !_pipModeEnabled) return;
    if (!reactionsEnabled || !_enableAnimations) return;
    unawaited(NativeBridge.triggerCompanionState(eventName));
  }

  /// Shows or hides the companion around a break when it is not pinned.
  ///
  /// A pinned companion is left exactly where the user put it — including
  /// closed, which is a deliberate choice we do not undo on the next break.
  void _applyBreakVisibility() {
    if (_companionKeepOnScreen) return;
    if (!_companionEnabled) return;
    if (_isPreviewMode) return;
    if (!_settingsRepo.currentSettings.hasCompletedOnboarding) return;

    if (_isBreakActive && !_isCompanionShown) {
      unawaited(_showNativeCompanion());
    } else if (!_isBreakActive && _isCompanionShown) {
      _isCompanionShown = false;
      unawaited(NativeBridge.hideCompanion());
      unawaited(NativeBridge.hidePipWindow());
    }
  }

  bool get isTransitioning => _isTransitioning;
  bool get companionEnabled => _companionEnabled;
  bool get pipModeEnabled => _pipModeEnabled;
  String get companionPetTheme => _companionPetTheme;
  String? get companionAvatarDefinition => _companionAvatarDefinition;
  bool get companionKeepOnScreen => _companionKeepOnScreen;
  String get companionPetName => _companionPetName;
  double get companionScale => _companionScale;
  bool get companionClickThrough => _companionClickThrough;
  bool get companionFollowMouse => _companionFollowMouse;
  String get pipBackgroundStyle => _pipBackgroundStyle;
  double get pipOpacity => _pipOpacity;
  bool get pipDraggableClickable => _pipDraggableClickable;
  String get companionToyType => _companionToyType;
  String get companionTreatType => _companionTreatType;
  bool get companionWanderingEnabled =>
      _settingsRepo.currentSettings.companionWanderingEnabled;

  /// The interaction toggles rolled into one comparable value.
  static String _interactionSignature(SettingsModel settings) =>
      '${settings.companionWanderingEnabled}/${settings.pettingEnabled}'
      '/${settings.ballThrowEnabled}/${settings.treatEnabled}'
      '/${settings.companionGazeEnabled}/${settings.companionGazeSensitivity}'
      '/${settings.companionIdleAnimation}/${settings.companionReactions}'
      '/${settings.companionReducedMotion}';

  String? _lastInteractionSignature;
  bool get pettingEnabled => _settingsRepo.currentSettings.pettingEnabled;
  bool get gazeEnabled => _settingsRepo.currentSettings.companionGazeEnabled;
  double get gazeSensitivity =>
      _settingsRepo.currentSettings.companionGazeSensitivity;
  bool get idleAnimationEnabled =>
      _settingsRepo.currentSettings.companionIdleAnimation;
  bool get reactionsEnabled => _settingsRepo.currentSettings.companionReactions;
  bool get reducedMotionEnabled =>
      _settingsRepo.currentSettings.companionReducedMotion;
  bool get ballThrowEnabled => _settingsRepo.currentSettings.ballThrowEnabled;
  bool get treatEnabled => _settingsRepo.currentSettings.treatEnabled;
  bool get isLowDistractionMode =>
      _companionClickThrough &&
      !_companionFollowMouse &&
      !_enableAnimations &&
      !companionWanderingEnabled;
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
    _companionAvatarDefinition = settings.companionAvatarDefinition;
    _companionKeepOnScreen = settings.companionKeepOnScreen;
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
    // Re-colouring or re-breeding the same species leaves the theme id alone,
    // so without this the customizer's changes never reach the overlay.
    final definitionChanged =
        _companionAvatarDefinition != settings.companionAvatarDefinition;
    final keepOnScreenChanged =
        _companionKeepOnScreen != settings.companionKeepOnScreen;

    // The overlay decides what to offer on hover from these, so a toggle the
    // user flips in settings has to reach it. They are compared as a group
    // because none of them is worth a field of its own.
    final interactions = _interactionSignature(settings);
    final interactionsChanged = _lastInteractionSignature != interactions;
    _lastInteractionSignature = interactions;

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
        !treatTypeChanged &&
        !definitionChanged &&
        !keepOnScreenChanged &&
        !interactionsChanged) {
      return; // Exit early if no companion settings have changed
    }

    _companionEnabled = settings.companionEnabled;
    _pipModeEnabled = settings.pipModeEnabled;
    _companionPetTheme = settings.companionPetTheme;
    _companionPetName = settings.companionPetName;
    _companionAvatarDefinition = settings.companionAvatarDefinition;
    _companionKeepOnScreen = settings.companionKeepOnScreen;
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

    final shouldShow = _companionEnabled && settings.hasCompletedOnboarding;

    final needsShowOrToggle =
        shouldShow && (!_isCompanionShown || pipModeChanged);
    final needsHide = !shouldShow && _isCompanionShown;

    if (needsShowOrToggle || needsHide) {
      debugPrint(
        '[CompanionOverlayController] Starting transition... needsShowOrToggle: $needsShowOrToggle, needsHide: $needsHide',
      );
      // The transition owns the loader from here, including one the toggle
      // raised before saving.
      _loaderFromToggle = false;
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
        try {
          if (needsShowOrToggle) {
            if (_isCompanionShown && pipModeChanged) {
              _isCompanionShown = false;
              debugPrint(
                '[CompanionOverlayController] Toggling modes, hiding current companion window...',
              );
              await NativeBridge.hideCompanion();
              await NativeBridge.hidePipWindow();
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
          if (_pipModeEnabled) {
            NativeBridge.showPipWindow(
              PipWindowArgs.fromMap(_companionPayload()),
            );
          }
        }
        if (nameChanged) {
          NativeBridge.updateCompanionName(_companionPetName);
          if (_pipModeEnabled) {
            NativeBridge.showPipWindow(
              PipWindowArgs.fromMap(_companionPayload()),
            );
          }
        }
        if (scaleChanged) {
          NativeBridge.updateCompanionScale(_companionScale);
          if (_pipModeEnabled) {
            NativeBridge.showPipWindow(
              PipWindowArgs.fromMap(_companionPayload()),
            );
          }
        }
        if (clickChanged) {
          NativeBridge.setCompanionClickThrough(_companionClickThrough);
        }
        if (followChanged) {
          NativeBridge.setCompanionFollowMouse(_companionFollowMouse);
        }
        if (keepOnScreenChanged) {
          // Un-pinning while no break is running should tidy the pet away now,
          // not at the end of the next break.
          _applyBreakVisibility();
        }
        if (definitionChanged ||
            keepOnScreenChanged ||
            animationsChanged ||
            backgroundChanged ||
            pipBackgroundStyleChanged ||
            pipOpacityChanged ||
            pipDraggableClickableChanged ||
            toyTypeChanged ||
            treatTypeChanged ||
            // Wandering and the hover interactions live only in the payload,
            // so without this a user unticking one of them would see no
            // change until something else happened to trigger a push.
            interactionsChanged) {
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
    _isCompanionShown = true;
    final ready = Completer<void>();
    _pipReady = ready;
    await NativeBridge.showPipWindow(
      PipWindowArgs.fromMap(_companionPayload()),
    );
    // The call returns once the window exists, but its engine is still
    // starting. Hold the caller (and so the loader) until the companion has
    // drawn its first frame, with a cap in case it never reports.
    await ready.future.timeout(
      const Duration(milliseconds: 2500),
      onTimeout: () {},
    );
    if (identical(_pipReady, ready)) _pipReady = null;
  }

  Completer<void>? _pipReady;

  static String buildQueryParamsForAvatar({
    required AvatarSpecies species,
    String? breed,
    String? paletteId,
    String bg = 'transparent',
  }) {
    String entityName = species.name;
    String? breedName = breed;

    if (breedName == null || breedName.isEmpty) {
      switch (species) {
        case AvatarSpecies.alpaca:
          breedName = 'cream-alpaca';
          break;
        case AvatarSpecies.beaver:
          breedName = 'north-american-beaver';
          break;
        case AvatarSpecies.capybara:
          breedName = 'capybara';
          break;
        case AvatarSpecies.cat:
          breedName = 'british-shorthair';
          break;
        case AvatarSpecies.chinchilla:
          breedName = 'gray-chinchilla';
          break;
        case AvatarSpecies.chick:
          breedName = 'yellow-chick';
          break;
        case AvatarSpecies.cow:
          breedName = 'dairy-cow';
          break;
        case AvatarSpecies.dog:
          breedName = 'shiba-inu';
          break;
        case AvatarSpecies.duck:
          breedName = 'mallard-duck';
          break;
        case AvatarSpecies.deer:
          breedName = 'sika-deer';
          break;
        case AvatarSpecies.fox:
          breedName = 'red-fox';
          break;
        case AvatarSpecies.ferret:
          breedName = 'sable-ferret';
          break;
        case AvatarSpecies.guineaPig:
          entityName = 'guinea-pig';
          breedName = 'american-guinea-pig';
          break;
        case AvatarSpecies.hamster:
          breedName = 'syrian-hamster';
          break;
        case AvatarSpecies.hedgehog:
          breedName = 'european-hedgehog';
          break;
        case AvatarSpecies.lion:
          breedName = 'african-lion';
          break;
        case AvatarSpecies.monkey:
          breedName = 'macaque';
          break;
        case AvatarSpecies.otter:
          breedName = 'sea-otter';
          break;
        case AvatarSpecies.owl:
          breedName = 'barn-owl';
          break;
        case AvatarSpecies.panda:
          entityName = 'bear';
          breedName = 'giant-panda';
          break;
        case AvatarSpecies.parrot:
          breedName = 'scarlet-macaw';
          break;
        case AvatarSpecies.penguin:
          breedName = 'emperor-penguin';
          break;
        case AvatarSpecies.pig:
          breedName = 'pink-pig';
          break;
        case AvatarSpecies.rabbit:
          breedName = 'holland-lop';
          break;
        case AvatarSpecies.raccoon:
          entityName = 'bear';
          breedName = 'raccoon';
          break;
        case AvatarSpecies.redPanda:
          entityName = 'bear';
          breedName = 'red-panda';
          break;
        case AvatarSpecies.sheep:
          breedName = 'white-sheep';
          break;
        case AvatarSpecies.seal:
          breedName = 'harbor-seal';
          break;
        case AvatarSpecies.squirrel:
          breedName = 'red-squirrel';
          break;
        case AvatarSpecies.tiger:
          breedName = 'bengal-tiger';
          break;
        case AvatarSpecies.wolf:
          entityName = 'dog';
          breedName = 'husky';
          break;
        case AvatarSpecies.bear:
          breedName = 'brown-bear';
          break;
        case AvatarSpecies.goose:
          breedName = 'greylag-goose';
          break;
      }
    } else {
      if (species == AvatarSpecies.guineaPig) entityName = 'guinea-pig';
      if (species == AvatarSpecies.panda ||
          species == AvatarSpecies.raccoon ||
          species == AvatarSpecies.redPanda) {
        entityName = 'bear';
      }
      if (species == AvatarSpecies.wolf) entityName = 'dog';
    }

    var query = 'entity=$entityName&breed=$breedName&nose=1&mouth=1&bg=$bg';
    if (paletteId != null && paletteId.isNotEmpty) {
      query += '&palette=$paletteId';
    }
    return query;
  }

  /// Which renderer the overlay should use for the current theme.
  String get _renderMode =>
      PetTheme.getTheme(_companionPetTheme).isBlobatar ? 'blob' : 'artwork';

  /// The appearance to send to the overlay windows.
  ///
  /// Prefers what the customizer saved. When nothing has been customized yet,
  /// the theme's own definition is encoded instead, so the overlay always has
  /// a complete description rather than having to guess from an id.
  String? _resolvedAvatarDefinitionJson() {
    final saved = _companionAvatarDefinition;
    if (saved != null && saved.isNotEmpty) return saved;

    final theme = PetTheme.getTheme(_companionPetTheme);
    final definition = theme.avatarDefinition;
    if (definition == null) return null;

    try {
      return jsonEncode(definition.toJson());
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
      return null;
    }
  }

  /// Persists the appearance the customizer produced and pushes it to the
  /// overlay windows.
  Future<void> saveAvatarDefinition(AvatarDefinition definition) async {
    final encoded = jsonEncode(definition.toJson());
    if (_companionAvatarDefinition == encoded) return;

    await _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(
        companionAvatarDefinition: encoded,
      ),
    );
  }

  Map<String, dynamic> _companionPayload() {
    return {
      'themeId': _companionPetTheme,
      'petName': _companionPetName,
      'scale': _companionScale,
      'clickThrough': _companionClickThrough,
      'followMouse': _companionFollowMouse,
      // Two switches have to agree: the user's own choice, and whether motion
      // is allowed at all. A companion that walks about while animations are
      // off would be the most conspicuous thing on the screen.
      'wanderingEnabled': companionWanderingEnabled && _enableAnimations,
      'pettingEnabled': pettingEnabled,
      'playEnabled': ballThrowEnabled,
      'treatEnabled': treatEnabled,
      'gazeEnabled': gazeEnabled,
      'gazeSensitivity': gazeSensitivity,
      'idleAnimation': idleAnimationEnabled,
      'reactionsEnabled': reactionsEnabled,
      'reducedMotion': reducedMotionEnabled,
      'animationsEnabled': _enableAnimations,
      'pipBackgroundStyle': _pipBackgroundStyle,
      'pipOpacity': _pipOpacity,
      'pipDraggableClickable': _pipDraggableClickable,
      'companionToyType': _companionToyType,
      'companionTreatType': _companionTreatType,
      'previewBackground': _companionPreviewBackground,
      // The overlay runs in its own engine and cannot read settings, so its
      // whole appearance has to travel with the payload.
      'avatarDefinitionJson': _resolvedAvatarDefinitionJson(),
      'renderMode': _renderMode,
      'keepOnScreen': _companionKeepOnScreen,
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

  /// True while the loader was raised by [toggleCompanion] and no transition
  /// has taken it over yet.
  bool _loaderFromToggle = false;

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
    openBlobatarNameDialogNotifier.dispose();
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
