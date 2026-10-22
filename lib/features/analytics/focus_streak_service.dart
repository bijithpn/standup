import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart'
    show StreakMilestone;

/// A second, complementary streak axis to [CompanionStreakService]'s
/// break-taking consistency: consecutive days whose Focus Score meets
/// [minFocusScore]. Deliberately mirrors [CompanionStreakService]'s exact
/// structure (same tier ladder, same persisted-highest-marker mechanism,
/// same companion `happy` reaction) — a different input signal, not a
/// competing progression system.
///
/// Unlike the break streak (which [StatsService] already tracks
/// incrementally), nothing maintains a running "focus streak" counter, so
/// this computes it on demand from [FocusSessionService]/[AppUsageService]
/// history each time it's checked, on the same periodic-timer pattern
/// [WeeklyDigestService] and [FocusInsightService] already use.
class FocusStreakService extends ChangeNotifier {
  static const _kHighestMilestoneDaysKey =
      'focus_highest_streak_milestone_days';
  static const _checkInterval = Duration(minutes: 15);

  /// A day counts toward the streak once its Focus Score reaches this share
  /// of tracked time — deliberately lower than a "great" day, since this is
  /// a consistency signal, not a personal-best one.
  static const double minFocusScore = 0.3;

  /// Data is pruned to 30 days upstream (see [AppUsageService]), so the
  /// streak can never exceed that — this just bounds the backward scan.
  static const int _maxScanDays = 40;

  final FocusSessionService _focusSessionService;
  final AppUsageService _usageService;
  final StorageService _storage;
  final EventBus _eventBus;

  int _highestMilestoneDays;
  Timer? _checkTimer;

  FocusStreakService({
    required FocusSessionService focusSessionService,
    required AppUsageService usageService,
    required StorageService storage,
    required EventBus eventBus,
  }) : _focusSessionService = focusSessionService,
       _usageService = usageService,
       _storage = storage,
       _eventBus = eventBus,
       _highestMilestoneDays = storage.getInt(
         _kHighestMilestoneDaysKey,
         defaultValue: 0,
       );

  void start() {
    _checkTimer ??= Timer.periodic(
      _checkInterval,
      (_) => checkAndMaybeCelebrate(),
    );
    checkAndMaybeCelebrate();
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// The highest tier already celebrated.
  StreakMilestone? get highestMilestone {
    for (final tier in StreakMilestone.tiers.reversed) {
      if (_highestMilestoneDays >= tier.days) return tier;
    }
    return null;
  }

  /// The next tier still to be reached, if any remain.
  StreakMilestone? get nextMilestone {
    for (final tier in StreakMilestone.tiers) {
      if (_highestMilestoneDays < tier.days) return tier;
    }
    return null;
  }

  /// Consecutive days (ending today) whose Focus Score met [minFocusScore].
  /// A day with *zero* tracked activity — today before usage lands, or any
  /// day genuinely away from the computer (sick day, vacation, weekend) —
  /// doesn't break the streak, since there's no work to have missed. A day
  /// that *had* activity but fell short of [minFocusScore] does.
  int currentStreakDays({DateTime? now}) {
    final today = now ?? clock.now();
    var streak = 0;

    for (var i = 0; i < _maxScanDays; i++) {
      final date = today.subtract(Duration(days: i));
      final totalActiveSeconds = _usageService
          .categoryTotals(UsagePeriod.today, now: date)
          .values
          .fold<int>(0, (sum, s) => sum + s);

      if (totalActiveSeconds == 0)
        continue; // no activity: a day off, not a break

      final dateKey = _dateKey(date);
      final score = _focusSessionService.focusScore(
        dateKey,
        totalActiveSeconds: totalActiveSeconds,
      );
      if (score < minFocusScore) break;
      streak++;
    }
    return streak;
  }

  void checkAndMaybeCelebrate({DateTime? now}) {
    final streak = currentStreakDays(now: now);
    if (streak <= _highestMilestoneDays) return;

    StreakMilestone? crossed;
    for (final tier in StreakMilestone.tiers) {
      if (streak >= tier.days && _highestMilestoneDays < tier.days) {
        crossed = tier;
      }
    }
    if (crossed == null) return;

    _highestMilestoneDays = crossed.days;
    _storage.setInt(_kHighestMilestoneDaysKey, _highestMilestoneDays);
    _eventBus.emit(
      CompanionInteractionEvent(
        interactionType: 'happy',
        metadata: {'reason': 'focus_streak_milestone', 'days': crossed.days},
      ),
    );
    notifyListeners();
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
