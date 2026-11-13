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

/// Counts consecutive days with focus score >= minFocusScore and emits a companion event when a new milestone tier is crossed.
class FocusStreakService extends ChangeNotifier {
  static const _kHighestMilestoneDaysKey =
      'focus_highest_streak_milestone_days';
  static const _checkInterval = Duration(minutes: 15);

  static const double minFocusScore = 0.3;

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

  StreakMilestone? get highestMilestone {
    for (final tier in StreakMilestone.tiers.reversed) {
      if (_highestMilestoneDays >= tier.days) return tier;
    }
    return null;
  }

  StreakMilestone? get nextMilestone {
    for (final tier in StreakMilestone.tiers) {
      if (_highestMilestoneDays < tier.days) return tier;
    }
    return null;
  }

  // Walks back from today; days with no tracked activity are skipped, a low-score day ends the streak.
  int currentStreakDays({DateTime? now}) {
    final today = now ?? clock.now();
    var streak = 0;

    for (var i = 0; i < _maxScanDays; i++) {
      final date = today.subtract(Duration(days: i));
      final totalActiveSeconds = _usageService
          .categoryTotals(UsagePeriod.today, now: date)
          .values
          .fold<int>(0, (sum, s) => sum + s);

      if (totalActiveSeconds == 0) {
        continue;
      }

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
