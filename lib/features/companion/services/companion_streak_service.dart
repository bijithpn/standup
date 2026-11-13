import 'package:flutter/foundation.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';

/// Streak tier that unlocks companion rewards.
class StreakMilestone {
  final int days;
  final String label;

  const StreakMilestone(this.days, this.label);

  static const List<StreakMilestone> tiers = [
    StreakMilestone(3, 'Getting Started'),
    StreakMilestone(7, 'One Week Strong'),
    StreakMilestone(14, 'Two Week Habit'),
    StreakMilestone(30, 'Monthly Master'),
    StreakMilestone(60, 'Two Month Champion'),
    StreakMilestone(100, 'Century Streak'),
  ];
}

/// Watches StatsService streaks and fires an event the first time a new milestone tier is reached; the highest tier is persisted.
class CompanionStreakService extends ChangeNotifier {
  static const _kHighestMilestoneDaysKey =
      'companion_highest_streak_milestone_days';

  final StatsService _statsService;
  final StorageService _storage;
  final EventBus _eventBus;

  int _highestMilestoneDays;

  CompanionStreakService({
    required StatsService statsService,
    required StorageService storage,
    required EventBus eventBus,
  }) : _statsService = statsService,
       _storage = storage,
       _eventBus = eventBus,
       _highestMilestoneDays = storage.getInt(
         _kHighestMilestoneDaysKey,
         defaultValue: 0,
       ) {
    _statsService.addListener(_onStatsChanged);
  }

  int get currentStreakDays => _statsService.stats.currentStreak;

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

  void _onStatsChanged() {
    final streak = _statsService.stats.currentStreak;
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
        metadata: {'reason': 'streak_milestone', 'days': crossed.days},
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _statsService.removeListener(_onStatsChanged);
    super.dispose();
  }
}
