import 'dart:async';
import 'package:clock/clock.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';

/// Polls every 15 min and fires the break-vs-focus insight notification once, when data is sufficient.
class FocusInsightService {
  static const _checkInterval = Duration(minutes: 15);

  static const _minDifferencePoints = 5.0;

  final StorageService _storage;
  final BreakHistoryService _breakHistoryService;
  final FocusSessionService _focusSessionService;
  final NotificationService _notificationService;

  Timer? _checkTimer;

  FocusInsightService({
    required StorageService storage,
    required BreakHistoryService breakHistoryService,
    required FocusSessionService focusSessionService,
    required NotificationService notificationService,
  }) : _storage = storage,
       _breakHistoryService = breakHistoryService,
       _focusSessionService = focusSessionService,
       _notificationService = notificationService;

  void start() {
    _checkTimer ??= Timer.periodic(_checkInterval, (_) => checkAndMaybeShow());
    checkAndMaybeShow();
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void checkAndMaybeShow({DateTime? now}) {
    final alreadyShown = _storage.getBool(AppConstants.keyFocusInsightShown);
    if (alreadyShown) return;

    final correlation = BreakFocusCorrelation.compute(
      events: _breakHistoryService.events,
      allSessions: _focusSessionService.sessionsForPeriod(
        UsagePeriod.month,
        now: now ?? clock.now(),
      ),
    );
    if (!correlation.hasEnoughData) return;
    if (correlation.differencePoints.abs() < _minDifferencePoints) return;

    _notificationService.showFocusCorrelationInsight(correlation);
    _storage.setBool(AppConstants.keyFocusInsightShown, true);
  }
}
