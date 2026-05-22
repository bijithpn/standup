import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/features/settings/break_profile.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/break_system/application/strict_mode_controller.dart';
import 'package:standup/features/settings/exercise_model.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

class BreakController extends ChangeNotifier {
  final TimerEngine _timerEngine;
  final SettingsRepository _settingsRepo;
  final StatsService _statsService;

  String? _currentExerciseTitle;
  String? _currentExerciseInstructions;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingMusic = false;

  String _currentTemplate = '';
  String _currentThemeName = 'random';
  bool _isPreviewMode = false;

  BreakController({
    required TimerEngine timerEngine,
    required SettingsRepository settingsRepo,
    required StatsService statsService,
  }) : _timerEngine = timerEngine,
       _settingsRepo = settingsRepo,
       _statsService = statsService {
    _timerEngine.addListener(_onTimerChanged);
  }

  TimerEngine get timerEngine => _timerEngine;
  SettingsRepository get settingsRepository => _settingsRepo;
  bool get isPaused => _timerEngine.state == TimerState.paused;
  bool get isBreakActive => _timerEngine.state == TimerState.breakActive;
  String? get currentExerciseTitle => _currentExerciseTitle;
  String? get currentExerciseInstructions => _currentExerciseInstructions;

  void initialize() {
    _applySettings();
    _timerEngine.startTimers();
    _statsService.load();

    // Listen for timer events to trigger global overlays
    _timerEngine.addListener(_handleGlobalOverlays);
  }

  void _handleGlobalOverlays() {
    final overlayService = sl<OverlayWindowService>();
    final strictModeController = sl<StrictModeController>();
    final settings = _settingsRepo.currentSettings;

    bool shouldShowBreak = _timerEngine.state == TimerState.breakActive;
    bool shouldShowWarning = _timerEngine.isPreBreak;

    if (shouldShowBreak) {
      final breakInfo = _timerEngine.activeBreak;

      // Attempt to enable native strict mode if requested
      if (settings.strictMode && !strictModeController.isStrictModeActive) {
        strictModeController.enableStrictMode();
      }

      if (overlayService.currentOverlayType != OverlayType.breakScreen) {
        if (strictModeController.isInMeeting) {
          debugPrint('Auto-postponing break due to active meeting.');
          _timerEngine.postponeBreak();
          return;
        }
        String? exerciseTitle;
        String? exerciseInstructions;

        if (settings.showExercisesInBreak) {
          final now = DateTime.now();
          final today = '${now.year}-${now.month}-${now.day}';
          List<String> shownToday = List.from(settings.shownExercisesToday);

          if (settings.lastExerciseDate != today) {
            shownToday.clear();
          }

          final availableExercises = settings.exercises.isEmpty
              ? ExerciseModel.defaults
              : settings.exercises;
          final enabledExercises = availableExercises
              .where((e) => e.enabled)
              .toList();
          final unshown = enabledExercises
              .where((e) => !shownToday.contains(e.id))
              .toList();

          if (unshown.isNotEmpty) {
            unshown.shuffle();
            final selected = unshown.first;
            exerciseTitle = selected.title;
            exerciseInstructions = selected.instructions;

            shownToday.add(selected.id);
            _settingsRepo.save(
              settings.copyWith(
                lastExerciseDate: today,
                shownExercisesToday: shownToday,
              ),
            );
          }
        }

        overlayService.showOverlay(
          type: OverlayType.breakScreen,
          builder: (context) => const SizedBox.shrink(),
          strictMode: settings.strictMode,
          showOnAllDisplays: settings.showOnAllDisplays,
          breakTheme: settings.breakTheme,
        );

        // Determine universal template and theme for all displays
        _currentTemplate =
            AppConstants.wellnessSlideshow[Random().nextInt(
              AppConstants.wellnessSlideshow.length,
            )];
        if (settings.breakTheme == 'random') {
          const themes = ['image', 'ocean', 'forest', 'minimal', 'sunset', 'nebula', 'midnight', 'cyberpunk', 'zen'];
          _currentThemeName = themes[Random().nextInt(themes.length)];
        } else {
          _currentThemeName = settings.breakTheme;
        }

        // Store these so we can pass them in updateOverlayData
        _currentExerciseTitle = exerciseTitle;
        _currentExerciseInstructions = exerciseInstructions;

        // Start background music if enabled
        if (settings.playMusicDuringBreak && !_isPlayingMusic) {
          _playLofiMusic();
        }
      }

      // Update all overlay engines with the current timer state
      if (breakInfo != null) {
        MacOSBridge.updateOverlayData({
          'title': breakInfo.title,
          'tip': breakInfo.tip,
          'durationSeconds': breakInfo.durationSeconds,
          'remainingSeconds': _timerEngine.countdownSeconds,
          'strictMode': settings.strictMode,
          'exerciseTitle': _currentExerciseTitle,
          'exerciseInstructions': _currentExerciseInstructions,
          'playMusic': settings.playMusicDuringBreak,
          'template': _currentTemplate,
          'theme': _currentThemeName,
          'breakTemplate': settings.breakTemplate,
          'companionCatTheme': settings.companionCatTheme,
        });
      }
    } else if (shouldShowWarning) {
      if (overlayService.currentOverlayType != OverlayType.preBreakWarning) {
        overlayService.showOverlay(
          type: OverlayType.preBreakWarning,
          builder: (context) => const SizedBox.shrink(),
        );
      }
    } else if (overlayService.isOverlayVisible && !_isPreviewMode &&
        (overlayService.currentOverlayType == OverlayType.breakScreen ||
            overlayService.currentOverlayType == OverlayType.preBreakWarning)) {
      if (strictModeController.isStrictModeActive) {
        strictModeController.disableStrictMode();
      }
      overlayService.hideOverlay();
      _stopMusic();
    }

    notifyListeners();
  }

  void _playLofiMusic() async {
    try {
      final random = Random().nextInt(6) + 1; // 1 to 6
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('music/lofi_$random.mp3'));
      _isPlayingMusic = true;
    } catch (e) {
      debugPrint("Failed to play lofi music: $e");
    }
  }

  void _stopMusic() async {
    if (_isPlayingMusic) {
      await _audioPlayer.stop();
      _isPlayingMusic = false;
    }
  }

  void _applySettings() {
    final settings = _settingsRepo.currentSettings;
    _timerEngine.updateSettings(
      shortIntervalMinutes: settings.shortBreakIntervalMinutes,
      shortDurationSeconds: settings.shortBreakDurationSeconds,
      longIntervalMinutes: settings.longBreakIntervalMinutes,
      longDurationSeconds: settings.longBreakDurationMinutes * 60,
      pauseAfterMinutes: settings.pauseTimerAfterMinutes,
      resetAfterMinutes: settings.resetTimerAfterMinutes,
    );
    _timerEngine.updateMenuStyle(settings.menuBarStyle);
    _timerEngine.setFocusMode(settings.focusModeEnabled);
    sl<NotificationService>().setNotificationsEnabled(
      settings.notificationsEnabled,
    );
    sl<NotificationService>().setSoundEnabled(settings.soundEnabled);
    sl<TrayManagerService>().setIconModeFromStyle(settings.trayIconStyle);
  }

  void togglePause() {
    if (isPaused) {
      _timerEngine.resumeTimers();
    } else {
      _timerEngine.pauseTimers();
    }
    sl<TrayManagerService>().updatePauseState(isPaused);
    notifyListeners();
  }

  void takeBreakNow() {
    _timerEngine.triggerBreakNow();
    sl<TrayManagerService>().setBreakActive(true);
  }

  void startTestBreak() {
    final overlayService = sl<OverlayWindowService>();
    final settings = _settingsRepo.currentSettings;
    _isPreviewMode = true;

    if (settings.showExercisesInBreak) {
      final availableExercises = settings.exercises.isEmpty
          ? ExerciseModel.defaults
          : settings.exercises;
      final enabledExercises = availableExercises
          .where((e) => e.enabled)
          .toList();
      if (enabledExercises.isNotEmpty) {
        enabledExercises.shuffle();
      }
    }

    overlayService.showOverlay(
      type: OverlayType.breakScreen,
      builder: (context) => const SizedBox.shrink(),
      strictMode: settings.strictMode,
      showOnAllDisplays: settings.showOnAllDisplays,
      breakTheme: settings.breakTheme,
    );
    _currentTemplate =
        AppConstants.wellnessSlideshow[Random().nextInt(
          AppConstants.wellnessSlideshow.length,
        )];
    if (settings.breakTheme == 'random') {
      const themes = ['image', 'ocean', 'forest', 'minimal', 'sunset', 'nebula', 'midnight', 'cyberpunk', 'zen'];
      _currentThemeName = themes[Random().nextInt(themes.length)];
    } else {
      _currentThemeName = settings.breakTheme;
    }

    MacOSBridge.updateOverlayData({
      'title': 'Test Break',
      'tip': 'This is a preview of your break screen.',
      'durationSeconds': 60,
      'remainingSeconds': 60,
      'strictMode': settings.strictMode,
      'type': OverlayType.breakScreen.name,
      'isPreview': true,
      'playMusic': settings.playMusicDuringBreak,
      'template': _currentTemplate,
      'theme': _currentThemeName,
      'breakTemplate': settings.breakTemplate,
      'companionCatTheme': settings.companionCatTheme,
    });

    if (settings.playMusicDuringBreak && !_isPlayingMusic) {
      _playLofiMusic();
    }
  }

  void skipNextBreak() {
    _timerEngine.skipNextBreak();
  }

  void skipCurrentBreak() {
    _isPreviewMode = false;
    if (!_settingsRepo.currentSettings.strictMode) {
      _timerEngine.finishBreak(skipped: true);
      sl<TrayManagerService>().setBreakActive(false);
      sl<OverlayWindowService>().hideOverlay();
      _stopMusic();
    }
  }

  void postponeCurrentBreak() {
    if (_timerEngine.canPostpone && !_settingsRepo.currentSettings.strictMode) {
      _timerEngine.postponeBreak();
    }
  }

  void completeCurrentBreak() {
    _isPreviewMode = false;
    _timerEngine.finishBreak(skipped: false);
    sl<TrayManagerService>().setBreakActive(false);
  }

  void onBreakCompleted() {
    // Force save timer state to persist the completed break
    _timerEngine.saveState();
    sl<TrayManagerService>().setBreakActive(false);
  }

  void refreshSettings() {
    _applySettings();
  }

  void changeProfile(BreakProfile profile) {
    final updated = _settingsRepo.currentSettings.copyWith(
      selectedProfileId: profile.id,
      shortBreakIntervalMinutes: profile.shortIntervalMinutes,
      shortBreakDurationSeconds: profile.shortDurationSeconds,
      longBreakIntervalMinutes: profile.longIntervalMinutes,
      longBreakDurationMinutes: profile.longDurationMinutes,
    );
    _settingsRepo.save(updated);
    _applySettings();
    notifyListeners();
  }

  void _onTimerChanged() {
    // Sync tray pause state if it changed externally (e.g. idle detection)
    sl<TrayManagerService>().updatePauseState(isPaused);

    // Track completed breaks when countdown reaches zero naturally
    if (_timerEngine.state == TimerState.running &&
        _timerEngine.activeBreak == null) {
      // Break just finished normally — already handled in finishBreak
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timerEngine.removeListener(_onTimerChanged);
    _audioPlayer.dispose();
    super.dispose();
  }
}
