import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/features/analytics/focus_session_detector.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_builder.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// Polls the active app every 10s while tracking is enabled, accumulates
/// seconds in memory, and flushes into [AppUsageService] every 30s. Only the
/// app's executable-derived name is stored (never the window title
/// `getActiveApp` also returns), to keep usage history at app-level detail
/// only.
///
/// The same tick also feeds an [ActivitySegmentBuilder], which records *when*
/// each stretch happened rather than only how long it lasted. Daily totals
/// alone cannot answer "what was I doing at 10am", so the timeline, per-app
/// sessions, and every time-of-day pattern are built on those segments. It
/// rides this existing loop deliberately — a second poller watching the same
/// thing would double the cost for the same information.
class AppUsageTracker {
  final AppTrackingService _appTracking;
  final AppUsageService _usageService;
  final SettingsRepository _settingsRepo;
  final ActivityMonitor _activityMonitor;
  final FocusSessionService? _focusSessionService;
  final ContextSwitchTracker? _contextSwitchTracker;
  final FocusSessionDetector _focusDetector = FocusSessionDetector();
  final ActivitySegmentRepository? _segments;
  final ActivitySegmentBuilder _segmentBuilder =
      ActivitySegmentBuilder(pollInterval: _pollInterval);
  final EventBus? _eventBus;
  StreamSubscription<AppEvent>? _eventSub;
  final AppLogger _logger = AppLogger();

  static const _pollInterval = Duration(seconds: 10);
  static const _flushInterval = Duration(seconds: 30);

  Timer? _pollTimer;
  Timer? _flushTimer;

  final Map<String, Map<String, int>> _pendingSeconds = {};
  final Map<String, String> _pendingNames = {};
  final Map<String, AppCategory> _pendingCategories = {};
  String? _lastAppKey;

  AppUsageTracker({
    required AppTrackingService appTracking,
    required AppUsageService usageService,
    required SettingsRepository settingsRepo,
    required ActivityMonitor activityMonitor,
    FocusSessionService? focusSessionService,
    ContextSwitchTracker? contextSwitchTracker,
    ActivitySegmentRepository? segmentRepository,
    EventBus? eventBus,
  })  : _segments = segmentRepository,
        _eventBus = eventBus,
        _appTracking = appTracking,
        _usageService = usageService,
        _settingsRepo = settingsRepo,
        _activityMonitor = activityMonitor,
        _focusSessionService = focusSessionService,
        _contextSwitchTracker = contextSwitchTracker;

  void start() {
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => tickOnce());
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => flushNow());

    // Breaks bracket the timeline: without them a break reads as idle, and
    // "where did the day go" cannot tell resting apart from walking away.
    _eventSub ??= _eventBus?.stream.listen((event) {
      if (event is BreakStartedEvent) {
        onBreakStarted(at: event.timestamp);
      } else if (event is BreakEndedEvent) {
        onBreakEnded(at: event.timestamp);
      }
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _eventSub?.cancel();
    _eventSub = null;
    _recordSegment(_segmentBuilder.close(clock.now()));
    flushNow();
    _recordFocusSession(_focusDetector.closeOpenSession());
  }

  /// A break started, so the stretch it interrupted ends here.
  ///
  /// [at] is the moment the break actually began. Events arrive asynchronously,
  /// so reading the clock on delivery would attribute the queueing delay to
  /// whatever the break interrupted.
  void onBreakStarted({DateTime? at}) =>
      _recordSegment(_segmentBuilder.onBreakStarted(at ?? clock.now()));

  /// The break ended; the next poll opens whatever comes after it.
  void onBreakEnded({DateTime? at}) =>
      _recordSegment(_segmentBuilder.onBreakEnded(at ?? clock.now()));

  @visibleForTesting
  Future<void> tickOnce() async {
    if (!_settingsRepo.currentSettings.appUsageTrackingEnabled) return;

    // Idle time is recorded rather than skipped: "where did the day go" needs
    // to account for the hour the machine sat untouched, not quietly drop it.
    if (_activityMonitor.isIdle) {
      _recordSegment(_segmentBuilder.onIdle(clock.now()));
      return;
    }

    try {
      final app = await _appTracking.getActiveApp();
      if (app == null) return;
      if (isBreakMateItself(app)) return;

      final appKey = _resolveAppKey(app);
      if (appKey == null) return;

      if (_lastAppKey != null && _lastAppKey != appKey) {
        _contextSwitchTracker?.recordSwitch(clock.now());
      }
      _lastAppKey = appKey;

      final displayName = _resolveDisplayName(app);
      final category = AppCategorizer.categorize(
        name: displayName,
        bundleId: app.bundleId,
      );

      final date = _todayString();
      final dayMap = _pendingSeconds.putIfAbsent(date, () => {});
      dayMap[appKey] = (dayMap[appKey] ?? 0) + _pollInterval.inSeconds;
      _pendingNames[appKey] = displayName;
      _pendingCategories[appKey] = category;

      _recordSegment(
        _segmentBuilder.onActive(
          appKey: appKey,
          appName: displayName,
          category: category,
          now: clock.now(),
        ),
      );

      _recordFocusSession(_focusDetector.onTick(category, clock.now()));
    } catch (e) {
      _logger.error('AppUsageTracker tick failed: $e');
    }
  }

  void _recordFocusSession(FocusSession? session) {
    if (session != null) _focusSessionService?.recordSession(session);
  }

  void _recordSegment(ActivitySegment? segment) {
    if (segment != null) _segments?.record(segment);
  }

  @visibleForTesting
  void flushNow() {
    _segments?.flush();
    _segments?.applyRetention(
      _settingsRepo.currentSettings.activityHistoryRetentionDays,
    );
    if (_pendingSeconds.isEmpty) return;

    for (final dateEntry in _pendingSeconds.entries) {
      for (final appEntry in dateEntry.value.entries) {
        _usageService.addUsageSeconds(
          date: dateEntry.key,
          appKey: appEntry.key,
          name: _pendingNames[appEntry.key] ?? appEntry.key,
          category: _pendingCategories[appEntry.key] ?? AppCategory.general,
          seconds: appEntry.value,
        );
      }
    }
    _pendingSeconds.clear();
  }

  /// True when the "active app" is BreakMate itself — its Settings window,
  /// the Desktop Companion overlay, or the break overlay briefly grabbing
  /// focus. BreakMate runs continuously in the background, so without this
  /// check its own windows taking focus (e.g. opening Settings to check
  /// stats) got counted as ordinary app usage, inflating its own tracked
  /// time far past any real foreground app.
  ///
  /// [ActiveAppInfo.bundleId] is the real bundle identifier on macOS
  /// (`com.bijith.breakmate`) and the full executable path on Windows —
  /// either way it reliably contains BreakMate's own identifier when
  /// BreakMate is frontmost (see AppTrackingBridge/app_tracking_bridge.cpp).
  @visibleForTesting
  static bool isBreakMateItself(ActiveAppInfo app) {
    final bundleId = app.bundleId.toLowerCase();
    // startsWith, not ==: flavored builds (e.g. the `dev` flavor's
    // `com.bijith.breakmate.dev`) append a suffix to the base bundle id, so
    // an exact match let BreakMate's own dev builds slip through and get
    // tracked as if they were another app.
    return bundleId.startsWith('com.bijith.breakmate') ||
        bundleId.contains('breakmateapp.exe');
  }

  /// bundleId is a real bundle identifier on macOS and the full exe path on
  /// Windows (see AppTrackingBridge/app_tracking_bridge.cpp) — either way
  /// it's a stable per-app key. Falls back to executableName if bundleId is
  /// unavailable.
  String? _resolveAppKey(ActiveAppInfo app) {
    final raw = app.bundleId != 'Unknown' ? app.bundleId : app.executableName;
    final key = raw.toLowerCase();
    if (key.isEmpty || key == 'unknown') return null;
    return key;
  }

  /// The executable's file name is a privacy-safe app label — unlike
  /// ActiveAppInfo.name, which macOS may populate with the active window's
  /// title. Only falls back to app.name if the executable name is missing.
  String _resolveDisplayName(ActiveAppInfo app) {
    var name = app.executableName;
    if (name.toLowerCase().endsWith('.exe')) {
      name = name.substring(0, name.length - 4);
    }
    if (name.isNotEmpty && name != 'Unknown') return name;
    return app.name;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
