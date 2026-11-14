import 'dart:async';

import 'package:flutter/services.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/away_break_service.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

typedef ActivityCallback = void Function(bool isActive);

enum AwayReason { sleeping, locked, sessionInactive }

/// Single source of truth for "is the user at the computer": native sleep/lock/session events, input idle polling and reconciliation.
///
/// Policy: idle time up to the threshold already counted as work and is discarded by the orchestrator on idle.
/// Away reasons (sleep/lock/session) freeze the engine immediately; it only wakes once every reason is gone and
/// fresh input is seen (or the platform has no idle provider, in which case the unlock/wake itself is the signal).
class ActivityMonitor {
  static const _channel = MethodChannel('com.breakmate.desktop/bridge');
  static const _pollInterval = Duration(seconds: 5);
  // Poll faster while waiting for the first input after unlock/wake so the timer resumes promptly.
  static const _confirmInterval = Duration(seconds: 1);
  // Input newer than this after unlock/wake counts as the user being back.
  static const _confirmIdleSeconds = 5.0;
  // Sleep begins a few seconds after the event; ignore input seen before this much time has passed.
  static const _staleSleepGuard = Duration(seconds: 20);

  final AppLogger _logger = AppLogger();
  final Set<AwayReason> _away = {};
  final Stopwatch _sinceAway = Stopwatch();

  bool _idle = false;
  bool _awaitingActivity = false;
  bool _polling = false;
  bool _started = false;
  Timer? _timer;

  /// null until the first poll; false when the platform has no working idle provider.
  bool? idleSupported;
  double lastIdleSeconds = 0;

  ActivityCallback? _onActivityChanged;
  void Function(double idleSeconds)? _onIdleSample;
  void Function(DateTime at)? _onAway;
  VoidCallback? _onBack;

  void setActivityCallback(ActivityCallback callback) =>
      _onActivityChanged = callback;

  void setIdleSampleCallback(void Function(double idleSeconds) callback) =>
      _onIdleSample = callback;

  /// [onAway] fires when the first away reason appears; [onBack] once all are gone and input is confirmed.
  void setAwayCallbacks({
    required void Function(DateTime at) onAway,
    required VoidCallback onBack,
  }) {
    _onAway = onAway;
    _onBack = onBack;
  }

  /// True whenever the user is not actively at the computer.
  bool get isIdle => _idle || _away.isNotEmpty || _awaitingActivity;
  Set<AwayReason> get awayReasons => Set.unmodifiable(_away);

  void start() {
    if (_started) return;
    _started = true;
    _logger.info('[ActivityMonitor] started');
    _schedule(Duration.zero);
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  void handleNative(String event, {int? atMs}) {
    switch (event) {
      case 'systemSleep':
        _add(
          AwayReason.sleeping,
          at: atMs == null ? null : DateTime.fromMillisecondsSinceEpoch(atMs),
        );
      case 'systemWake':
        _remove(AwayReason.sleeping);
      case 'sessionLocked':
        if (_settings.pauseOnLock) _add(AwayReason.locked);
      case 'sessionUnlocked':
        _remove(AwayReason.locked);
      case 'sessionInactive':
        _add(AwayReason.sessionInactive);
      case 'sessionActive':
        _remove(AwayReason.sessionInactive);
    }
  }

  SettingsModel get _settings => sl<SettingsRepository>().currentSettings;

  void _add(AwayReason reason, {DateTime? at}) {
    if (!_away.add(reason)) return;
    _logger.info('[ActivityMonitor] away +${reason.name} -> $_away');
    if (_away.length > 1) return;
    _awaitingActivity = false;
    _idle = false;
    _sinceAway
      ..reset()
      ..start();
    _onAway?.call(at ?? DateTime.now());
  }

  void _remove(AwayReason reason) {
    if (!_away.remove(reason)) return;
    _logger.info('[ActivityMonitor] away -${reason.name} -> $_away');
    if (_away.isNotEmpty) return;
    _awaitingActivity = true;
    _schedule(Duration.zero);
  }

  void _schedule(Duration after) {
    if (!_started) return;
    _timer?.cancel();
    _timer = Timer(after, _poll);
  }

  Future<void> _poll() async {
    if (_polling || !_started) return;
    _polling = true;
    try {
      final idle = await _readIdle();
      await _reconcileSession();
      _evaluate(idle);
    } finally {
      _polling = false;
      _schedule(_awaitingActivity ? _confirmInterval : _pollInterval);
    }
  }

  Future<double?> _readIdle() async {
    try {
      final v = await _channel.invokeMethod<double>('getIdleTime');
      if (idleSupported != true) {
        _logger.info('[ActivityMonitor] idle provider available');
      }
      idleSupported = true;
      return v;
    } on MissingPluginException {
      return _unsupported();
    } on PlatformException catch (e) {
      return _unsupported(e.message);
    }
  }

  double? _unsupported([String? why]) {
    if (idleSupported != false) {
      _logger.warning(
        '[ActivityMonitor] idle detection unavailable${why == null ? '' : ': $why'}; '
        'only sleep/lock events will pause the timer',
      );
    }
    idleSupported = false;
    return null;
  }

  /// Catches missed lock/unlock/session events and a missed wake notification.
  Future<void> _reconcileSession() async {
    try {
      final s = await _channel.invokeMapMethod<String, dynamic>(
        'getSessionState',
      );
      final locked = s?['locked'] as bool?;
      final active = s?['active'] as bool?;
      if (locked != null && _settings.pauseOnLock) {
        locked
            ? _add(AwayReason.locked)
            : _remove(AwayReason.locked);
      }
      if (active != null) {
        active
            ? _remove(AwayReason.sessionInactive)
            : _add(AwayReason.sessionInactive);
      }
    } on MissingPluginException {
      // Platform without a session query: events alone drive lock state.
    } on PlatformException catch (e) {
      _logger.warning('[ActivityMonitor] session query failed: ${e.message}');
    }
  }

  void _evaluate(double? idle) {
    if (idle != null) {
      lastIdleSeconds = idle;
      _onIdleSample?.call(idle);
      AwayBreakService.instance.handleIdleTimeUpdate(idle);
    }

    // Poll code only runs while the process is awake, so an old sleep flag with fresh input means a missed wake event.
    if (_away.contains(AwayReason.sleeping) &&
        _sinceAway.elapsed > _staleSleepGuard &&
        idle != null &&
        idle < 2) {
      _logger.warning('[ActivityMonitor] stale sleep flag with input; clearing');
      _remove(AwayReason.sleeping);
    }
    if (_away.isNotEmpty) return;

    if (_awaitingActivity) {
      if (idle == null || idle < _confirmIdleSeconds) {
        _awaitingActivity = false;
        _logger.info('[ActivityMonitor] activity confirmed; returning');
        _onBack?.call();
      }
      return;
    }

    if (idle == null) return;
    final shouldBeIdle =
        _settings.autoPauseOnIdle &&
        idle >= _settings.pauseTimerAfterMinutes * 60;
    if (shouldBeIdle == _idle) return;
    _idle = shouldBeIdle;
    _logger.info(
      '[ActivityMonitor] state ${shouldBeIdle ? 'ACTIVE -> IDLE' : 'IDLE -> ACTIVE'} '
      '(idle ${idle.round()}s, threshold ${_settings.pauseTimerAfterMinutes}m)',
    );
    _onActivityChanged?.call(!shouldBeIdle);
  }

  void dispose() => stop();
}
