import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:clock/clock.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/features/analytics/insights_overview.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// Every 15 min shows at most one top insight per day (notification plus companion speech), plus evening eye-care and end-of-day summary.
class DailyInsightNotifierService {
  static const _checkInterval = Duration(minutes: 15);

  final StorageService _storage;
  final AppUsageService _usageService;
  final FocusSessionService _focusSessionService;
  final BreakHistoryService _breakHistoryService;
  final FocusStreakService _streakService;
  final SettingsRepository _settingsRepository;
  final NotificationService _notificationService;

  Timer? _checkTimer;

  DailyInsightNotifierService({
    required StorageService storage,
    required AppUsageService usageService,
    required FocusSessionService focusSessionService,
    required BreakHistoryService breakHistoryService,
    required FocusStreakService streakService,
    required SettingsRepository settingsRepository,
    required NotificationService notificationService,
  }) : _storage = storage,
       _usageService = usageService,
       _focusSessionService = focusSessionService,
       _breakHistoryService = breakHistoryService,
       _streakService = streakService,
       _settingsRepository = settingsRepository,
       _notificationService = notificationService;

  void start() {
    _checkTimer ??= Timer.periodic(_checkInterval, (_) {
      checkAndMaybeShow();
      _maybeShowEveningEyeCare();
    });
    checkAndMaybeShow();
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void checkAndMaybeShow({DateTime? now}) {
    final today = now ?? clock.now();
    final todayKey = _dateKey(today);
    final lastShown = _storage.getString(
      AppConstants.keyLastDailyInsightDateKey,
    );
    if (lastShown == todayKey) return;

    final insight = _topInsight(today);
    if (insight == null) return;

    _notificationService.showDailyInsight(insight.text);
    IpcBridge.instance.dispatch(
      IpcEvent.companionInteraction(
        interactionType: 'speech',
        metadata: {'text': insight.text},
      ),
    );
    _storage.setString(AppConstants.keyLastDailyInsightDateKey, todayKey);
  }

  // After 8pm, once per day: enables macOS Night Shift and notifies.
  void _maybeShowEveningEyeCare() {
    final now = clock.now();
    if (now.hour < 20 ||
        !_settingsRepository.currentSettings.eveningEyeCare ||
        _storage.getString('last_evening_eye_care') == _dateKey(now)) {
      return;
    }
    _storage.setString('last_evening_eye_care', _dateKey(now));
    _enableNightShift().then(_notificationService.showEveningEyeCare);
  }

  static const _bridge = MethodChannel('com.breakmate.desktop/bridge');

  Future<bool> _enableNightShift() async {
    if (!Platform.isMacOS) return false;
    try {
      return await _bridge.invokeMethod<bool>('setNightShift', true) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Notifies breaks taken/total and focus time for today; skipped when there is no data.
  void showEndOfDaySummary({DateTime? now}) {
    final today = now ?? clock.now();
    final events = _breakHistoryService.eventsBetween(
      DateTime(today.year, today.month, today.day),
      today.add(const Duration(seconds: 1)),
    );
    final taken = events.where((e) => e.completed).length;
    final focus = Duration(
      seconds: _focusSessionService.focusSecondsForPeriod(
        UsagePeriod.today,
        now: today,
      ),
    );
    if (events.isEmpty && focus == Duration.zero) return;
    _notificationService.showEndOfDaySummary(
      '$taken/${events.length} breaks taken · '
      '${focus.inHours}h ${focus.inMinutes % 60}m focused',
    );
  }

  OverviewInsight? _topInsight(DateTime today) {
    final settings = _settingsRepository.currentSettings;

    final weeklyBreaks = _breakHistoryService.eventsBetween(
      today.subtract(const Duration(days: 7)),
      today,
    );
    final completed = weeklyBreaks.where((e) => e.completed).length;
    final skipped = weeklyBreaks.length - completed;

    final correlation = BreakFocusCorrelation.compute(
      events: _breakHistoryService.events,
      allSessions: _focusSessionService.sessionsForPeriod(
        UsagePeriod.month,
        now: today,
      ),
    );

    final insights = buildOverviewInsights(
      todayCategoryTotals: _usageService.categoryTotals(
        UsagePeriod.today,
        now: today,
      ),
      budgetMinutes: settings.categoryDailyBudgetMinutes,
      correlation: correlation,
      focusStreakDays: _streakService.currentStreakDays(now: today),
      breaksCompletedThisWeek: completed,
      breaksSkippedThisWeek: skipped,
      breakEvents: _breakHistoryService.events,
      focusSessions: _focusSessionService.sessionsForPeriod(
        UsagePeriod.month,
        now: today,
      ),
      limit: 1,
    );
    return insights.isEmpty ? null : insights.first;
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
