import 'package:clock/clock.dart';
import 'package:breakmate/core/services/snooze_timer.dart';
import 'dart:math';
import 'package:breakmate/features/settings/exercise_model.dart';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
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
import 'package:breakmate/core/services/soundscape_service.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// UI-facing controller over [TimerEngine]: opens/closes the break overlay window, runs focus sessions, snooze, soundscapes and hotkeys.
class BreakController extends ChangeNotifier {
  final AppLogger _logger = AppLogger();
  final TimerEngine _timerEngine;
  final SettingsRepository _settingsRepo;
  final StatsService _statsService;

  String? _currentExerciseTitle;
  String? _currentExerciseInstructions;

  final SnoozeTimer _snoozeTimer = SnoozeTimer();
  DateTime? get snoozeResumeAt => _snoozeTimer.resumeAt;
  int? _breakStartedAtMs;
  bool _soundscapeActive = false;
  bool _soundscapeSuspended = false;

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

  // Settings edits re-apply timers/services and refresh an already-open break overlay.
  void _onSettingsChanged() {
    _applySettings();
    if (isBreakActive &&
        _settingsRepo.currentSettings.experience.hasExerciseRestrictions) {
      _pickRandomExercise();
    }
    _updateActiveOverlay();
    notifyListeners();
  }

  void _onTimerChanged() {
    if (!isPaused) _snoozeTimer.cancel();
    notifyListeners();
  }

  /// Starts the timers and subscribes to timer changes so overlays follow the timer state.
  void initialize() {
    _applySettings();
    _timerEngine.startTimers();
    _statsService.load();

    _timerEngine.addListener(_handleGlobalOverlays);
  }

  /// Reacts to every timer tick: shows the break overlay on break start, the pre-break warning in the last 3s, and tears down on end.
  void _handleGlobalOverlays() {
    final overlayService = sl<OverlayWindowService>();
    final strictModeController = sl<StrictModeController>();
    final settings = _settingsRepo.currentSettings;

    bool shouldShowBreak = _timerEngine.state == TimerState.breakActive;
    final isMeetingActive = _timerEngine.contextManager.isMeetingActive();
    final isPresenting = _timerEngine.contextManager.isPresentationActive();
    // The quiet reminder at break time already covers meetings; a long warning toast over a screen share would not be quiet.
    final shouldShowWarning =
        _timerEngine.isPreBreak && !isMeetingActive && !isPresenting;

    if (!shouldShowWarning) {
      if (_hasShownPreBreakWarning &&
          !shouldShowBreak &&
          overlayService.currentOverlayType == OverlayType.preBreakWarning) {
        overlayService.hideOverlay();
      }
      _hasShownPreBreakWarning = false;
    }

    if (shouldShowBreak && _lastOverlayState != TimerState.breakActive) {
      // Guards against re-showing the overlay on every tick of the same break.
      _lastOverlayState = TimerState.breakActive;

      _breakStartedAtMs = DateTime.now().millisecondsSinceEpoch;

      if (isMeetingActive || isPresenting) {
        if (!_hasShownMeetingBreakNotice) {
          _hasShownMeetingBreakNotice = true;
          sl<NotificationService>().showMeetingBreakReminder(
            isPresenting: isPresenting && !isMeetingActive,
          );
        }
      }

      if (_microExercise != null ||
          settings.showExercisesInBreak ||
          settings.experience.hasExerciseRestrictions) {
        _pickRandomExercise();
      }

      final data = _breakOverlayData(settings);
      overlayService.showOverlay(
        type: OverlayType.breakScreen,
        builder: (_) => const SizedBox.shrink(),
        strictMode: data['strictMode'] as bool,
        breakTheme: settings.breakTheme,
        showOnAllDisplays: settings.showOnAllDisplays,
        // Sent over IPC to the overlay process, which parses it into OverlayWindowConfig.
        overlayData: data,
      );

      if (data['strictMode'] as bool) {
        strictModeController.enableStrictMode();
      }

      _startSoundscape(settings);
    } else if (shouldShowWarning &&
        !_hasShownPreBreakWarning &&
        !overlayService.isOverlayVisible) {
      if (_timerEngine.countdownSeconds > 0) {
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
      _breakStartedAtMs = null;
      _stopSoundscape();
    }

    _syncSoundscapeSleep();
  }

  bool get _isQuietContext {
    final c = _timerEngine.contextManager;
    return c.isMeetingActive() || c.isPresentationActive();
  }

  BreakDisplayMode _resolveDisplayMode(
    SettingsModel settings, {
    required bool isLong,
  }) {
    // A compact window cannot enforce a lock, so strict breaks stay immersive.
    // Meetings and presentations never get an immersive window.
    if (_isQuietContext) return BreakDisplayMode.compact;
    if (settings.strictMode) return BreakDisplayMode.immersive;
    final mode = BreakDisplayMode.values.asNameMap()[settings.breakDisplayMode];
    return switch (mode) {
      BreakDisplayMode.immersive => BreakDisplayMode.immersive,
      BreakDisplayMode.automatic => AutoModeRules(
        longBreaksImmersive: settings.longBreaksImmersive,
      ).resolve(isLongBreak: isLong),
      _ => BreakDisplayMode.compact,
    };
  }

  Map<String, dynamic> _displayData(
    SettingsModel settings, {
    required bool isLong,
    required String focus,
    bool preview = false,
  }) {
    final mode = _resolveDisplayMode(settings, isLong: isLong);
    return {
      'strictMode':
          !preview && settings.strictMode && mode == BreakDisplayMode.immersive,
      'windowMode': mode.name,
      'compactCorner': settings.compactCorner,
      'compactWidth': 360,
      'compactHeight': 244,
      'motionIntensity': settings.motionIntensity,
      'timeOfDay': settings.adaptToTimeOfDay,
      'soundscape': settings.soundscape,
      'soundscapeVolume': settings.soundscapeVolume,
      'breakStartedAtMs':
          _breakStartedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      'paused': _timerEngine.systemSleepPaused,
      'breakFocus': focus,
    };
  }

  Map<String, dynamic> _breakOverlayData(SettingsModel settings) {
    final isLong = _timerEngine.activeBreak?.type == BreakType.long;
    return {
      'isLong': isLong,
      'breakType': _timerEngine.activeBreak?.type.name,
      'template': settings.breakTemplate,
      'breakTemplate': settings.breakTemplate,
      'companionPetTheme': settings.companionPetTheme,
      'enableAnimations': settings.enableAnimations,
      'intensityLevel': settings.intensityLevel,
      'showWellnessNotes': settings.showExercisesInBreak,
      'experience': settings.experience.toMap(),
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
      ..._displayData(
        settings,
        isLong: isLong,
        focus: isLong || _microExercise != null ? 'stretch' : 'eyes',
      ),
    };
  }

  Soundscape _soundscapeOf(SettingsModel settings) =>
      Soundscape.values.asNameMap()[settings.soundscape] ?? Soundscape.silence;

  void _startSoundscape(SettingsModel settings) {
    final scape = _soundscapeOf(settings);
    if (scape == Soundscape.silence) return;
    _soundscapeActive = true;
    _soundscapeSuspended = false;
    sl<SoundscapeService>().start(
      scape,
      settings.soundscapeVolume,
      muted:
          settings.quietModeEnabled ||
          !settings.soundEnabled ||
          _isQuietContext,
    );
  }

  void _stopSoundscape({bool immediate = false}) {
    if (!_soundscapeActive) return;
    _soundscapeActive = false;
    _soundscapeSuspended = false;
    sl<SoundscapeService>().stop(immediate: immediate);
  }

  void _syncSoundscapeSleep() {
    if (!_soundscapeActive) return;
    final asleep = _timerEngine.systemSleepPaused;
    if (asleep == _soundscapeSuspended) return;
    _soundscapeSuspended = asleep;
    final service = sl<SoundscapeService>();
    asleep ? service.suspend() : service.resume();
  }

  String? _currentExerciseId;

  ExerciseModel? _microExercise;

  /// Short stretch/posture break triggered on demand; the picked exercise forces the "activities" template.
  void startMicroSession() {
    final stretches = _settingsRepo
        .getExercises()
        .where(
          (e) =>
              e.category == ExerciseCategory.stretch ||
              e.category == ExerciseCategory.posture,
        )
        .toList();
    _microExercise = ExerciseModel.pickForBreak(
      stretches,
      Random(),
      avoidId: _currentExerciseId,
      preferences: _settingsRepo.currentSettings.experience,
    );
    _timerEngine.triggerBreakNow(
      durationSeconds: _microExercise?.durationSeconds,
    );
    notifyListeners();
  }

  DateTime? _focusStartedAt;
  DateTime? _focusEndsAt;
  Timer? _focusTimer;

  bool get isFocusSessionActive => _focusEndsAt != null;

  /// Pauses break timers and (optionally) enables DND until [minutes] elapse; persisted so it survives a restart.
  void startFocusSession(int minutes) {
    _snoozeTimer.cancel();
    endFocusSession(completed: false);
    final now = DateTime.now();
    _beginFocus(now, now.add(Duration(minutes: minutes)));
    _timerEngine.pauseTimers(isManual: true);
    _setDoNotDisturb(true);
    notifyListeners();
  }

  void _beginFocus(DateTime start, DateTime end) {
    _focusStartedAt = start;
    _focusEndsAt = end;
    final storage = sl<StorageService>();
    storage.setInt('focus_started_ms', start.millisecondsSinceEpoch);
    storage.setInt('focus_ends_ms', end.millisecondsSinceEpoch);
    _focusTimer?.cancel();
    _focusTimer = Timer(end.difference(DateTime.now()), () {
      endFocusSession(completed: true);
    });
  }

  /// Resumes or finalises a focus session saved before the app was closed.
  void restoreFocusSession() {
    final storage = sl<StorageService>();
    final endMs = storage.getInt('focus_ends_ms', defaultValue: 0);
    if (endMs == 0 || _focusEndsAt != null) return;
    final start = DateTime.fromMillisecondsSinceEpoch(
      storage.getInt('focus_started_ms', defaultValue: endMs),
    );
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    _beginFocus(start, end);
    if (end.isAfter(DateTime.now())) {
      _timerEngine.pauseTimers(isManual: true);
      notifyListeners();
    } else {
      endFocusSession(completed: true);
    }
  }

  /// Ends the session, resumes timers and logs it as a FocusSession if it lasted at least a minute.
  void endFocusSession({required bool completed}) {
    final start = _focusStartedAt;
    final end = _focusEndsAt;
    if (start == null || end == null) return;
    _focusTimer?.cancel();
    _focusStartedAt = null;
    _focusEndsAt = null;
    final storage = sl<StorageService>();
    storage.setInt('focus_started_ms', 0);
    storage.setInt('focus_ends_ms', 0);
    if (isPaused) _timerEngine.resumeTimers();
    _setDoNotDisturb(false);

    final worked = (completed ? end : DateTime.now()).difference(start);
    if (worked >= const Duration(minutes: 1)) {
      sl<FocusSessionService>().recordSession(
        FocusSession(
          category: AppCategory.general,
          start: start,
          durationSeconds: worked.inSeconds,
        ),
      );
    }
    if (completed) {
      sl<NotificationService>().showReminder(
        message: 'Focus session complete — time for a break.',
      );
    }
    notifyListeners();
  }

  // Runs a user-installed macOS Shortcut named "BreakMate Focus On/Off"; no-op elsewhere.
  void _setDoNotDisturb(bool on) {
    if (!Platform.isMacOS || !_settingsRepo.currentSettings.focusDndEnabled) {
      return;
    }
    Process.run('shortcuts', ['run', 'BreakMate Focus ${on ? 'On' : 'Off'}']);
  }

  void _pickRandomExercise() {
    final micro =
        _microExercise?.effectiveTraits.matches(
              _settingsRepo.currentSettings.experience,
            ) ==
            true
        ? _microExercise
        : null;
    final exercise =
        micro ??
        ExerciseModel.pickForBreak(
          _settingsRepo.getExercises(),
          Random(),
          avoidId: _currentExerciseId,
          preferences: _settingsRepo.currentSettings.experience,
        );
    if (exercise == null) {
      _currentExerciseId = null;
      _currentExerciseTitle = null;
      _currentExerciseInstructions = null;
      return;
    }
    _currentExerciseId = exercise.id;
    _currentExerciseTitle = exercise.title;
    _currentExerciseInstructions = exercise.instructions;
  }

  /// Pushes current settings into the timer engine and starts/stops the detection and hotkey services.
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
    sl<NotificationService>().setNotificationsEnabled(
      settings.notificationsEnabled,
    );
    sl<NotificationService>().setSoundEnabled(settings.soundEnabled);
    sl<TrayManagerService>().setIconModeFromStyle(settings.trayIconStyle);

    final smartDetection = sl<SmartDetectionService>();
    if (settings.detectVideoCalls) {
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

  void showTimerExplanation() {
    final explanation = buildTimerExplanation(
      timerState: _timerEngine.state,
      contextManager: _timerEngine.contextManager,
      settings: _settingsRepo.currentSettings,
      snoozeResumeAt: snoozeResumeAt,
      isManualPause: _timerEngine.isManuallyPaused,
    );
    TimerExplanationOverlayService.show(explanation);
  }

  /// Manually pauses timers for [minutes] and auto-resumes unless the user resumed earlier.
  void snooze({int? minutes}) {
    if (isBreakActive || isFocusSessionActive) return;
    final snoozeMins =
        (minutes ?? _settingsRepo.currentSettings.lastSnoozeDurationMinutes)
            .clamp(1, 1440);
    _snoozeTimer.start(Duration(minutes: snoozeMins), () {
      if (isPaused) _timerEngine.resumeTimers(isManual: false);
      notifyListeners();
    });
    _timerEngine.pauseTimers(isManual: true);

    _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(
        lastSnoozeDurationMinutes: snoozeMins,
      ),
    );
    notifyListeners();
  }

  void snoozeUntil(DateTime endTime) {
    final remaining = endTime.difference(clock.now());
    if (remaining <= Duration.zero || isBreakActive || isFocusSessionActive) {
      return;
    }
    // Keep the exact meeting end; rounding down could interrupt its final minute.
    _snoozeTimer.start(remaining, () {
      if (isPaused) _timerEngine.resumeTimers(isManual: false);
      notifyListeners();
    });
    _timerEngine.pauseTimers(isManual: true);
    notifyListeners();
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
      if (snoozeResumeAt != null) {
        return 'Snoozed. Your focus countdown resumes at the time shown below.';
      }
      if (isFocusSessionActive) {
        return 'Paused: focus session active. Resumes when your session ends.';
      }
      if (_timerEngine.isManuallyPaused) {
        return 'Paused manually. Resume when you are ready.';
      }
      final context = _timerEngine.contextManager;
      if (!context.isWithinWorkingHours()) {
        return 'Paused: outside working hours or during lunch. Resumes automatically when your schedule allows.';
      }
      if (context.isSmartPauseActive()) {
        return context.isPresentationActive()
            ? 'Paused: presentation detected. Resumes when it ends.'
            : 'Paused: video playback detected. Resumes when it ends.';
      }
      return 'Paused. Resume when you are ready.';
    }
    if (_timerEngine.contextManager.isMeetingActive()) {
      return 'Meeting detected: the timer continues and breaks use quiet reminders.';
    }
    if (settings.quietModeEnabled) {
      return _quietModeLabel(settings.quietModePreset);
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

  /// Shows the overlay with sample data and auto-closes after 10s; flagged isPreview so nothing is recorded.
  void previewBreak({String? templateId}) {
    final overlayService = sl<OverlayWindowService>();
    final settings = _settingsRepo.currentSettings;
    final activeTemplate = templateId ?? settings.breakTemplate;

    _logger.info('Starting break preview for template: $activeTemplate');

    overlayService.showOverlay(
      type: OverlayType.breakScreen,
      builder: (_) => const SizedBox.shrink(),
      isPreview: true,
      overlayData: {
        'isLong': false,
        'breakType': 'short',
        'template': activeTemplate,
        'breakTemplate': activeTemplate,
        'companionPetTheme': settings.companionPetTheme,
        'enableAnimations': settings.enableAnimations,
        'intensityLevel': settings.intensityLevel,
        'showWellnessNotes': settings.showExercisesInBreak,
        'experience': settings.experience.toMap(),
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
        ..._displayData(settings, isLong: false, focus: 'eyes', preview: true),
      },
    );

    _startSoundscape(settings);
    Timer(const Duration(seconds: 10), () {
      if (overlayService.isOverlayVisible &&
          overlayService.currentOverlayType == OverlayType.breakScreen) {
        overlayService.hideOverlay();
        _stopSoundscape();
      }
    });
  }

  /// Finishes the break normally; wellness stats and chime are skipped in meetings/presentations.
  Future<void> completeCurrentBreak({bool lookedAway = false}) async {
    await _timerEngine.finishBreak(skipped: false);
    if (lookedAway || _microExercise != null) {
      _statsService.recordWellnessAction();
    }
    _microExercise = null;

    final context = _timerEngine.contextManager;
    if (_settingsRepo.currentSettings.breakChimeEnabled &&
        !context.isMeetingActive() &&
        !context.isPresentationActive()) {
      _playChime();
    }
    notifyListeners();
  }

  @visibleForTesting
  Future<void> Function()? onChime;

  Future<void> _playChime() async {
    final override = onChime;
    if (override != null) return override();
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.first.then((_) => player.dispose());
      await player.play(AssetSource('audio/break_chime.wav'), volume: 0.6);
    } catch (e) {
      _logger.warning('Failed to play completion chime: $e');
    }
  }

  /// Ends the break as skipped (counts toward skipped stats).
  Future<void> skipCurrentBreak() async {
    _microExercise = null;
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
    _snoozeTimer.cancel();
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

  // Re-sends overlay data so setting changes apply live to a break already on screen.
  void _updateActiveOverlay() {
    if (_timerEngine.state == TimerState.breakActive) {
      final overlayService = sl<OverlayWindowService>();
      final settings = _settingsRepo.currentSettings;
      final data = _breakOverlayData(settings);

      overlayService.showOverlay(
        type: OverlayType.breakScreen,
        builder: (_) => const SizedBox.shrink(),
        strictMode: data['strictMode'] as bool,
        breakTheme: settings.breakTheme,
        showOnAllDisplays: settings.showOnAllDisplays,
        overlayData: data,
      );
      if (_soundscapeActive) {
        sl<SoundscapeService>().setVolume(settings.soundscapeVolume);
      }
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

  void _emit(AppEvent event) {
    sl<EventBus>().emit(event);
  }

  @override
  void dispose() {
    _timerEngine.removeListener(_onTimerChanged);
    _settingsRepo.removeListener(_onSettingsChanged);
    _focusTimer?.cancel();
    _snoozeTimer.cancel();
    _stopSoundscape(immediate: true);
    super.dispose();
  }
}
