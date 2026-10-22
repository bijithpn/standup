import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/analytics/stats_service.dart';

/// Starts a fresh logical day exactly once per local calendar day.
///
/// What resets: the day's accumulated work time, the in-progress focus cycle
/// (so a countdown from the previous day is never carried over), the clock-out
/// latch, the saved session and the daily break counters. What never resets:
/// settings, training plans, privacy settings, goals and historical stats.
///
/// Triggers are event driven rather than polled: app start, a one-shot timer
/// armed for the next local midnight, and system wake/unlock (a Dart timer
/// that expires while the Mac sleeps only fires late, so wake reconciles).
///
/// Policies:
///  * Local calendar day (`yyyy-MM-dd`), computed with the `DateTime`
///    constructor so DST days of 23 or 25 hours are handled correctly.
///  * The last reset day is persisted, so a restart after midnight resets once
///    and repeated wake/lifecycle events are no-ops.
///  * A reset only moves forward. If the local date goes backwards (travelling
///    west across time zones, clock changes) nothing is reset or re-stamped.
///  * An active break that crosses midnight is left alone; the reset is
///    deferred until the break ends, and the break is attributed to the day
///    it ended on. No completion event is emitted or restarted by the reset.
class DailyResetService {
  static const String storageKey = 'daily_reset_date';

  final StorageService _storage;
  final TimerEngine _timerEngine;
  final StatsService _statsService;
  final SessionStateRepository _sessionStateRepository;
  final AppLogger _logger = AppLogger();

  Timer? _midnightTimer;
  bool _pending = false;
  bool _started = false;

  DailyResetService({
    required StorageService storage,
    required TimerEngine timerEngine,
    required StatsService statsService,
    required SessionStateRepository sessionStateRepository,
  }) : _storage = storage,
       _timerEngine = timerEngine,
       _statsService = statsService,
       _sessionStateRepository = sessionStateRepository;

  @visibleForTesting
  bool get hasPendingReset => _pending;

  @visibleForTesting
  bool get isMidnightTimerArmed => _midnightTimer?.isActive ?? false;

  /// Idempotent: calling it twice never duplicates the listener or timer.
  void start() {
    if (_started) {
      reconcile();
      return;
    }
    _started = true;
    _timerEngine.addListener(_onEngineChanged);
    reconcile();
  }

  void dispose() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    if (_started) _timerEngine.removeListener(_onEngineChanged);
    _started = false;
  }

  /// Call after the system wakes or the screen unlocks.
  void onSystemWake() => reconcile();

  /// Resets if the local day moved forward since the last reset.
  /// Returns true when a reset ran.
  bool reconcile() {
    try {
      return _reconcile();
    } finally {
      _armMidnightTimer();
    }
  }

  bool _reconcile() {
    final today = _dayKey(clock.now());
    final last = _storage.getString(storageKey);

    if (last.isEmpty) {
      // First run (or first launch after upgrade): nothing to reset yet.
      _storage.setString(storageKey, today);
      return false;
    }
    if (today.compareTo(last) <= 0) {
      _pending = false;
      return false;
    }

    // Clear before resetting: the engine notifies its listeners synchronously,
    // and `_onEngineChanged` must not re-enter while this reset is running.
    _pending = false;
    // Stamp first so any re-entrant reconcile sees the day as already handled.
    _storage.setString(storageKey, today);
    if (!_timerEngine.resetForNewDay()) {
      _storage.setString(storageKey, last);
      _pending = true; // break in progress; retried when it ends.
      _logger.info('Daily reset deferred: break active across midnight');
      return false;
    }

    _sessionStateRepository.clearSession();
    unawaited(_statsService.rolloverIfNeeded());
    _logger.info('Daily reset performed for $today (previous: $last)');
    return true;
  }

  void _onEngineChanged() {
    if (_pending && _timerEngine.state != TimerState.breakActive) {
      reconcile();
    }
  }

  void _armMidnightTimer() {
    if (!_started) return;
    _midnightTimer?.cancel();
    final now = clock.now();
    // `DateTime(y, m, d + 1)` normalises month/year overflow and respects DST.
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // One extra second keeps us safely past the boundary.
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(delay, reconcile);
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
