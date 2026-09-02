import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/features/analytics/focus_session_detector.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// Polls the active app every 10s while tracking is enabled and the user
/// isn't idle, accumulates seconds in memory, and flushes into
/// [AppUsageService] every 30s. Only the app's executable-derived name is
/// stored (never the window title `getActiveApp` also returns), to keep
/// usage history at app-level detail only.
class AppUsageTracker {
  final AppTrackingService _appTracking;
  final AppUsageService _usageService;
  final SettingsRepository _settingsRepo;
  final ActivityMonitor _activityMonitor;
  final FocusSessionService? _focusSessionService;
  final ContextSwitchTracker? _contextSwitchTracker;
  final FocusSessionDetector _focusDetector = FocusSessionDetector();
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
  })  : _appTracking = appTracking,
        _usageService = usageService,
        _settingsRepo = settingsRepo,
        _activityMonitor = activityMonitor,
        _focusSessionService = focusSessionService,
        _contextSwitchTracker = contextSwitchTracker;

  void start() {
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => tickOnce());
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => flushNow());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    flushNow();
    _recordFocusSession(_focusDetector.closeOpenSession());
  }

  @visibleForTesting
  Future<void> tickOnce() async {
    if (!_settingsRepo.currentSettings.appUsageTrackingEnabled) return;
    if (_activityMonitor.isIdle) return;

    try {
      final app = await _appTracking.getActiveApp();
      if (app == null) return;

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

      _recordFocusSession(_focusDetector.onTick(category, clock.now()));
    } catch (e) {
      _logger.error('AppUsageTracker tick failed: $e');
    }
  }

  void _recordFocusSession(FocusSession? session) {
    if (session != null) _focusSessionService?.recordSession(session);
  }

  @visibleForTesting
  void flushNow() {
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
