import 'dart:math';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/core/constants/app_constants.dart';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/break_profile.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/strict_mode_controller.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/global_hotkey_service.dart';
import 'package:breakmate/core/native/explain_hotkey_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/services/timer_explanation.dart';
import 'package:breakmate/core/services/timer_explanation_overlay_service.dart';
import 'package:audioplayers/audioplayers.dart';

class BreakController extends ChangeNotifier with WidgetsBindingObserver {
  final AppLogger _logger = AppLogger();
  final TimerEngine _timerEngine;
  final SettingsRepository _settingsRepo;
  final StatsService _statsService;

  String? _currentExerciseTitle;
  String? _currentExerciseInstructions;

  AudioPlayer? _audioPlayer;
  bool _isPlayingMusic = false;
  Timer? _fadeTimer;
  double _currentVolume = 0.0;

  String _currentTemplate = '';
  String _classicImage = '';

  TimerState? _lastOverlayState;
  bool _hasShownPreBreakWarning = false;
  bool _hasShownMeetingBreakNotice = false;

  BreakController({
    required TimerEngine timerEngine,
    required SettingsRepository settingsRepo,
    required StatsService statsService,
  }) : _timerEngine = timerEngine,
       _settingsRepo = settingsRepo,
       _statsService = statsService {
    _timerEngine.addListener(_onTimerChanged);
    _settingsRepo.addListener(_onSettingsChanged);
  }

  TimerEngine get timerEngine => _timerEngine;
  SettingsRepository get settingsRepository => _settingsRepo;
  bool get isPaused => _timerEngine.state == TimerState.paused;
  bool get isBreakActive => _timerEngine.state == TimerState.breakActive;
  Duration get totalWorkToday => _timerEngine.totalWorkToday;
  String? get currentExerciseTitle => _currentExerciseTitle;
  String? get currentExerciseInstructions => _currentExerciseInstructions;

  void _onSettingsChanged() {
    _applySettings();
    _updateActiveOverlay();
    notifyListeners();
  }

  void _onTimerChanged() {
    notifyListeners();
  }

  void initialize() {
    _applySettings();
    _timerEngine.startTimers();
    _statsService.load();

    _audioPlayer = AudioPlayer();
    _audioPlayer!.setReleaseMode(ReleaseMode.loop);

    _timerEngine.addListener(_handleGlobalOverlays);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_fadeTimer != null && _fadeTimer!.isActive) {
        _fadeTimer!.cancel();
        if (_isPlayingMusic) {
          _currentVolume = 1.0;
        } else {
          _currentVolume = 0.0;
        }
        _audioPlayer?.setVolume(_currentVolume);
      }
    }
  }

  void _handleGlobalOverlays() {
    final overlayService = sl<OverlayWindowService>();
    final strictModeController = sl<StrictModeController>();
    final settings = _settingsRepo.currentSettings;

    bool shouldShowBreak = _timerEngine.state == TimerState.breakActive;
    bool shouldShowWarning = _timerEngine.isPreBreak;
    final isMeetingActive = _timerEngine.contextManager.isMeetingActive();
    final isPresenting = _timerEngine.contextManager.isPresentationActive();

    if (!shouldShowWarning) {
      _hasShownPreBreakWarning = false;
    }

    if (shouldShowBreak && _lastOverlayState != TimerState.breakActive) {
      _lastOverlayState = TimerState.breakActive;

      final isLong = _timerEngine.activeBreak?.type == BreakType.long;
      _currentTemplate = settings.breakTemplate;

      if (isMeetingActive || isPresenting) {
        if (!_hasShownMeetingBreakNotice) {
          _hasShownMeetingBreakNotice = true;
          sl<NotificationService>().showMeetingBreakReminder(
            isPresenting: isPresenting && !isMeetingActive,
          );
        }
      }

      if (_currentTemplate == 'activities') {
        _pickRandomExercise();
      }

      _classicImage = AppConstants.wellnessSlideshow.isNotEmpty
          ? AppConstants.wellnessSlideshow[Random().nextInt(
              AppConstants.wellnessSlideshow.length,
            )]
          : '';

      overlayService.showOverlay(
        type: OverlayType.breakScreen,
        builder: (_) =>
            const SizedBox.shrink(), // Overlay UI is rendered in separate window
        strictMode: settings.strictMode,
        breakTheme: settings.breakTheme,
        showOnAllDisplays: settings.showOnAllDisplays,
        overlayData: {
          'isLong': isLong,
          'breakType': _timerEngine.activeBreak?.type.name,
          'template': _currentTemplate,
          'breakTemplate': _currentTemplate,
          'classicImage': _classicImage,
          'companionPetTheme': settings.companionPetTheme,
          'enableAnimations': settings.enableAnimations,
          'intensityLevel': settings.intensityLevel,
          'showWellnessNotes': settings.showExercisesInBreak,
          'durationSeconds':
              _timerEngine.activeBreak?.durationSeconds ??
              _timerEngine.countdownSeconds,
          'remainingSeconds': _timerEngine.countdownSeconds,
          'targetEndTime': _timerEngine.targetEndTime?.millisecondsSinceEpoch,
          'exerciseTitle': _currentExerciseTitle,
          'exerciseInstructions': _currentExerciseInstructions,
          'breaksCompleted': _statsService.stats.breaksCompleted,
          'clockFaceTextColorHex': settings.clockFaceTextColorHex,
          'clockFaceBlurEnabled': settings.clockFaceBlurEnabled,
          'overlayThemeMode': settings.overlayThemeMode,
          'breathPreset': settings.breathPreset,
          'lookedAwayPromptEnabled': settings.lookedAwayPromptEnabled,
          'customImagePath': settings.customImagePath ?? '',
        },
      );

      if (settings.strictMode) {
        strictModeController.enableStrictMode();
      }

      if (settings.playMusicDuringBreak) {
        _startMusic();
      }
    } else if (shouldShowWarning &&
        !_hasShownPreBreakWarning &&
        !overlayService.isOverlayVisible) {
      if (_timerEngine.countdownSeconds <= 3) {
        _hasShownPreBreakWarning = true;
        overlayService.showOverlay(
          type: OverlayType.preBreakWarning,
          builder: (_) => const SizedBox.shrink(),
          reminderType: 'breakStart',
          overlayData: {
            'overlayType': 'preBreakWarning',
            'type': 'preBreakWarning',
            'secondsRemaining': _timerEngine.countdownSeconds,
            'remainingSeconds': _timerEngine.countdownSeconds,
            'durationSeconds': _timerEngine.countdownSeconds,
            'targetEndTime': DateTime.now()
                .add(Duration(seconds: _timerEngine.countdownSeconds))
                .millisecondsSinceEpoch,
          },
        );
      }
    } else if (!shouldShowBreak &&
        !shouldShowWarning &&
        _lastOverlayState != null) {
      _lastOverlayState = null;
      _hasShownMeetingBreakNotice = false;
      overlayService.hideOverlay();
      strictModeController.disableStrictMode();
      _stopMusic();
    }
  }

  String? _currentExerciseId;

  void _pickRandomExercise() {
    final exercise = ExerciseModel.pickForBreak(
      _settingsRepo.getExercises(),
      Random(),
      avoidId: _currentExerciseId,
    );
    if (exercise == null) return;
    _currentExerciseId = exercise.id;
    _currentExerciseTitle = exercise.title;
    _currentExerciseInstructions = exercise.instructions;
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

    final smartDetection = sl<SmartDetectionService>();
    if (settings.detectVideoCalls || settings.respectFocusMode) {
      smartDetection.start();
    } else {
      smartDetection.stop();
    }

    final meetingDetection = sl<MeetingDetectionService>();
    if (settings.detectMeetings) {
      meetingDetection.start();
    } else {
      meetingDetection.stop();
    }

    // Kept running regardless of presentationPauseEnabled: that setting only
    // controls whether a presentation pauses the work timer, while the
    // detector itself is also used to keep the full break overlay off a
    // screen that's being presented/shared (see _handleGlobalOverlays).
    sl<PresentationDetectionService>().start();

    final hotkeyService = sl<GlobalHotkeyService>();
    if (settings.globalHotkeyEnabled) {
      hotkeyService.start(
        onPressed: () {
          if (isBreakActive) {
            skipCurrentBreak();
          } else {
            takeBreakNow();
          }
        },
      );
    } else {
      hotkeyService.stop();
    }

    final explainHotkeyService = sl<ExplainHotkeyService>();
    if (settings.globalHotkeyEnabled) {
      explainHotkeyService.start(onPressed: showTimerExplanation);
    } else {
      explainHotkeyService.stop();
    }
  }

  /// Phase 2's "why did BreakMate do that?" panel — opened by
  /// `⌘⌥E`/`Ctrl+Alt+E` ([ExplainHotkeyService]), shown via
  /// [TimerExplanationOverlayService]. Templated text over state this
  /// controller and [TimerContextManager] already expose; no AI call.
  void showTimerExplanation() {
    final explanation = buildTimerExplanation(
      timerState: _timerEngine.state,
      contextManager: _timerEngine.contextManager,
      settings: _settingsRepo.currentSettings,
    );
    TimerExplanationOverlayService.show(explanation);
  }

  void snooze({int? minutes}) {
    final snoozeMins =
        minutes ?? _settingsRepo.currentSettings.lastSnoozeDurationMinutes;
    _timerEngine.pauseTimers(isManual: true);

    Timer(Duration(minutes: snoozeMins), () {
      if (isPaused) {
        _timerEngine.resumeTimers();
      }
    });

    _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(
        lastSnoozeDurationMinutes: snoozeMins,
      ),
    );
    notifyListeners();
  }

  void snoozeUntil(DateTime endTime) {
    final minutes = endTime.difference(DateTime.now()).inMinutes.clamp(1, 240);
    snooze(minutes: minutes);
  }

  bool get quietModeEnabled => _settingsRepo.currentSettings.quietModeEnabled;
  String get quietModePreset => _settingsRepo.currentSettings.quietModePreset;

  bool get companionEnabled => _settingsRepo.currentSettings.companionEnabled;

  String get pauseReason {
    final settings = _settingsRepo.currentSettings;
    if (_timerEngine.state == TimerState.breakActive) {
      return settings.strictMode
          ? 'Break active. Strict controls are enforced.'
          : 'Break active. Skip is available from the overlay.';
    }
    if (_timerEngine.state == TimerState.paused) {
      if (settings.quietModeEnabled) {
        return _quietModeLabel(settings.quietModePreset);
      }
      return 'Paused manually.';
    }
    if (settings.calendarEnabled) {
      return 'Calendar-aware planning is watching for meeting conflicts.';
    }
    if (settings.detectMeetings || settings.detectVideoCalls) {
      return 'Meeting-aware mode is ready.';
    }
    return 'Running on your selected break profile.';
  }

  String _quietModeLabel(String preset) {
    switch (preset) {
      case 'presenting':
        return 'Quiet mode: presenting.';
      case 'meeting':
        return 'Quiet mode: meeting-heavy day.';
      case 'deep_work':
        return 'Quiet mode: deep work.';
      case 'low_battery':
        return 'Quiet mode: low battery.';
      default:
        return 'Quiet mode is enabled.';
    }
  }

  void toggleCompanion() {
    sl<CompanionOverlayController>().toggleCompanion(!companionEnabled);
  }

  void toggleQuietMode() {
    final current = _settingsRepo.currentSettings;
    final newValue = !current.quietModeEnabled;
    _settingsRepo.save(current.copyWith(quietModeEnabled: newValue));
    _applySettings();
    notifyListeners();
  }

  void setQuietModePreset(String preset) {
    _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(quietModePreset: preset),
    );
    notifyListeners();
  }

  void takeBreakNow() {
    _timerEngine.triggerBreakNow(isLong: false);
    notifyListeners();
  }

  void previewBreak({String? templateId}) {
    final overlayService = sl<OverlayWindowService>();
    final settings = _settingsRepo.currentSettings;
    final activeTemplate = templateId ?? settings.breakTemplate;

    _logger.info('Starting break preview for template: $activeTemplate');

    _classicImage = AppConstants.wellnessSlideshow.isNotEmpty
        ? AppConstants.wellnessSlideshow[Random().nextInt(
            AppConstants.wellnessSlideshow.length,
          )]
        : '';

    overlayService.showOverlay(
      type: OverlayType.breakScreen,
      builder: (_) => const SizedBox.shrink(),
      isPreview: true,
      overlayData: {
        'isLong': false,
        'breakType': activeTemplate == 'wind_down' ? 'windDown' : 'short',
        'template': activeTemplate,
        'breakTemplate': activeTemplate,
        'classicImage': _classicImage,
        'companionPetTheme': settings.companionPetTheme,
        'enableAnimations': settings.enableAnimations,
        'intensityLevel': settings.intensityLevel,
        'showWellnessNotes': settings.showExercisesInBreak,
        'exerciseTitle': 'Preview Mode',
        'exerciseInstructions':
            'This is a preview of your selected break template. It will not be recorded in your history.',
        'durationSeconds': settings.shortBreakDurationSeconds,
        'remainingSeconds': settings.shortBreakDurationSeconds,
        'targetEndTime': DateTime.now()
            .add(Duration(seconds: settings.shortBreakDurationSeconds))
            .millisecondsSinceEpoch,
        'breaksCompleted': _statsService.stats.breaksCompleted,
        'clockFaceTextColorHex': settings.clockFaceTextColorHex,
        'clockFaceBlurEnabled': settings.clockFaceBlurEnabled,
        'overlayThemeMode': settings.overlayThemeMode,
        'breathPreset': settings.breathPreset,
        'lookedAwayPromptEnabled': settings.lookedAwayPromptEnabled,
        'customImagePath': settings.customImagePath ?? '',
      },
    );

    Timer(const Duration(seconds: 10), () {
      if (overlayService.isOverlayVisible &&
          overlayService.currentOverlayType == OverlayType.breakScreen) {
        overlayService.hideOverlay();
      }
    });
  }

  /// [lookedAway] is true when the user confirmed they looked away from the
  /// screen during an eye-rest break; it counts as a wellness action.
  Future<void> completeCurrentBreak({bool lookedAway = false}) async {
    await _timerEngine.finishBreak(skipped: false);
    if (lookedAway) _statsService.recordWellnessAction();
    if (_settingsRepo.currentSettings.breakChimeEnabled) _playChime();
    notifyListeners();
  }

  /// A short, soft bell for a break that ran to its end. Fire and forget: a
  /// missing audio device must never affect the break flow.
  Future<void> _playChime() async {
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.first.then((_) => player.dispose());
      await player.play(AssetSource('audio/break_chime.wav'), volume: 0.6);
    } catch (e) {
      _logger.warning('Failed to play completion chime: $e');
    }
  }

  Future<void> skipCurrentBreak() async {
    await _timerEngine.finishBreak(skipped: true);
    notifyListeners();
  }

  void skipNextBreak() {
    _timerEngine.stateData.workElapsed = Duration.zero;
    _emit(BreakEndedEvent(skipped: true));
    notifyListeners();
  }

  void postponeCurrentBreak() {
    _timerEngine.postponeBreak();
    notifyListeners();
  }

  void togglePause() {
    if (isPaused) {
      _timerEngine.resumeTimers();
    } else {
      _timerEngine.pauseTimers(isManual: true);
    }
    notifyListeners();
  }

  void refreshSettings() {
    _applySettings();
    _updateActiveOverlay();
    notifyListeners();
  }

  void _updateActiveOverlay() {
    if (_timerEngine.state == TimerState.breakActive) {
      final overlayService = sl<OverlayWindowService>();
      final settings = _settingsRepo.currentSettings;
      final isLong = _timerEngine.activeBreak?.type == BreakType.long;

      overlayService.showOverlay(
        type: OverlayType.breakScreen,
        builder: (_) => const SizedBox.shrink(),
        strictMode: settings.strictMode,
        breakTheme: settings.breakTheme,
        showOnAllDisplays: settings.showOnAllDisplays,
        overlayData: {
          'isLong': isLong,
          'breakType': _timerEngine.activeBreak?.type.name,
          'template': settings.breakTemplate,
          'breakTemplate': settings.breakTemplate,
          'companionPetTheme': settings.companionPetTheme,
          'enableAnimations': settings.enableAnimations,
          'intensityLevel': settings.intensityLevel,
          'showWellnessNotes': settings.showExercisesInBreak,
          'durationSeconds':
              _timerEngine.activeBreak?.durationSeconds ??
              _timerEngine.countdownSeconds,
          'remainingSeconds': _timerEngine.countdownSeconds,
          'targetEndTime': _timerEngine.targetEndTime?.millisecondsSinceEpoch,
          'exerciseTitle': _currentExerciseTitle,
          'exerciseInstructions': _currentExerciseInstructions,
          'breaksCompleted': _statsService.stats.breaksCompleted,
          'clockFaceTextColorHex': settings.clockFaceTextColorHex,
          'clockFaceBlurEnabled': settings.clockFaceBlurEnabled,
          'overlayThemeMode': settings.overlayThemeMode,
          'breathPreset': settings.breathPreset,
          'lookedAwayPromptEnabled': settings.lookedAwayPromptEnabled,
          'customImagePath': settings.customImagePath ?? '',
        },
      );
    }
  }

  void changeProfile(BreakProfile profile) {
    _timerEngine.updateSettings(
      shortIntervalMinutes: profile.shortIntervalMinutes,
      shortDurationSeconds: profile.shortDurationSeconds,
      longIntervalMinutes: profile.longIntervalMinutes,
      longDurationSeconds: profile.longDurationMinutes * 60,
    );
    _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(
        selectedProfileId: profile.id,
        shortBreakIntervalMinutes: profile.shortIntervalMinutes,
        shortBreakDurationSeconds: profile.shortDurationSeconds,
        longBreakIntervalMinutes: profile.longIntervalMinutes,
        longBreakDurationMinutes: profile.longDurationMinutes,
      ),
    );
    notifyListeners();
  }

  Future<void> _startMusic() async {
    if (_isPlayingMusic) return;
    _isPlayingMusic = true;

    try {
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer!.setSource(AssetSource('music/lofi_1.mp3'));
      }

      await _audioPlayer!.resume();
      _audioPlayer!.setVolume(0);
      _fadeVolume(1.0);
    } catch (e) {
      _isPlayingMusic = false;
      _logger.warning('Failed to play music: $e');
    }
  }

  Future<void> _stopMusic() async {
    if (!_isPlayingMusic) return;
    _isPlayingMusic = false;

    _fadeVolume(
      0.0,
      onComplete: () {
        _audioPlayer?.pause();
      },
    );
  }

  void _fadeVolume(double target, {VoidCallback? onComplete}) {
    _fadeTimer?.cancel();
    const steps = 20;
    final delta = (target - _currentVolume) / steps;

    _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _currentVolume += delta;
      if ((delta > 0 && _currentVolume >= target) ||
          (delta < 0 && _currentVolume <= target)) {
        _currentVolume = target;
        timer.cancel();
        onComplete?.call();
      }
      _audioPlayer?.setVolume(_currentVolume);
    });
  }

  void _emit(AppEvent event) {
    sl<EventBus>().emit(event);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerEngine.removeListener(_onTimerChanged);
    _settingsRepo.removeListener(_onSettingsChanged);
    _audioPlayer?.dispose();
    super.dispose();
  }
}
