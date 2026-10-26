// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'companion_overlay_controller.dart';

extension CompanionOverlaySettingActions on CompanionOverlayController {
  Future<void> toggleCompanion(bool enabled) async {
    if (_companionEnabled == enabled || _isTransitioning) return;

    // Show the loader now. Saving settings and starting the companion's own
    // engine both take a moment, and a switch that appears to do nothing for a
    // second is worse than one that visibly works.
    final showLoader = enabled && !_isTransitioning;
    if (showLoader) {
      _isTransitioning = true;
      _loaderFromToggle = true;
      notifyListeners();
    }

    final updated = _settingsRepo.currentSettings.copyWith(
      companionEnabled: enabled,
      pipModeEnabled: true,
    );
    try {
      await _settingsRepo.save(updated);
    } finally {
      // If the change did not lead to a transition of its own (nothing needed
      // starting), nobody else will clear the loader.
      if (_loaderFromToggle) {
        _loaderFromToggle = false;
        _isTransitioning = false;
        notifyListeners();
      }
    }
  }

  Future<void> changeTheme(String themeId) async {
    if (_companionPetTheme == themeId || _isTransitioning) return;

    // Evict existing pet assets and clear cached SpriteSheets to release memory before loading the new theme.
    // This prevents GPU memory overhead from accumulative sprite sheets when the breed is toggled.
    PetAssetLoader.clearCache();

    final species = PetTheme.getTheme(themeId).species;
    final random = Random();
    final List<String> names;

    if (themeId == 'blobatar' || PetTheme.getTheme(themeId).isBlobatar) {
      names = CompanionOverlayController.blobatarNames;
    } else if (species == PetSpecies.dog) {
      names = CompanionOverlayController.dogNames;
    } else if (species == PetSpecies.flamingo) {
      names = CompanionOverlayController.flamingoNames;
    } else {
      names = CompanionOverlayController.catNames;
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
    final nextName = trimmedName.isEmpty
        ? (_companionPetTheme == 'blobatar' ? 'Blobby' : 'Mochi')
        : trimmedName;
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

  Future<void> changeWandering(bool enabled) async {
    if (companionWanderingEnabled == enabled || _isTransitioning) return;

    final updated = _settingsRepo.currentSettings.copyWith(
      companionWanderingEnabled: enabled,
    );
    await _settingsRepo.save(updated);
  }

  Future<void> setLowDistractionMode(bool enabled) async {
    final current = _settingsRepo.currentSettings;
    final updated = current.copyWith(
      companionClickThrough: enabled ? true : current.companionClickThrough,
      companionFollowMouse: enabled ? false : current.companionFollowMouse,
      // Wandering is the single most distracting thing the companion does, so
      // low-distraction mode has to stop it as well.
      companionWanderingEnabled: enabled
          ? false
          : current.companionWanderingEnabled,
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

  Future<void> changeGazeEnabled(bool value) async {
    await _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(companionGazeEnabled: value),
    );
  }

  Future<void> changeGazeSensitivity(double value) async {
    await _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(
        companionGazeSensitivity: value.clamp(0.0, 1.0),
      ),
    );
  }

  Future<void> changeIdleAnimation(bool value) async {
    await _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(companionIdleAnimation: value),
    );
  }

  Future<void> changeReactionsEnabled(bool value) async {
    await _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(companionReactions: value),
    );
  }

  Future<void> changeReducedMotion(bool value) async {
    await _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(companionReducedMotion: value),
    );
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
}
