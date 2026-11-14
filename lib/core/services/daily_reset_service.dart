import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/analytics/stats_service.dart';

/// Resets the timer and rolls stats over once per calendar day (at midnight or on wake), deferring if a break is active.
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

  void onSystemWake() => reconcile();

  /// Compares today with the stored reset date, resets if newer, and always re-arms the midnight timer.
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
      _storage.setString(storageKey, today);
      return false;
    }
    if (today.compareTo(last) <= 0) {
      _pending = false;
      return false;
    }

    _pending = false;

    _storage.setString(storageKey, today);
    // Date is stored first and reverted if the engine refuses (break active across midnight).
    if (!_timerEngine.resetForNewDay()) {
      _storage.setString(storageKey, last);
      // Retried from _onEngineChanged once the break ends.
      _pending = true;
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

    final nextMidnight = DateTime(now.year, now.month, now.day + 1);

    // +1s so the timer fires just after the date has actually changed.
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(delay, reconcile);
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
