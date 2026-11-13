import 'dart:convert';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/wellness/domain/wellness_engine.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';

/// Learns per-hour activity from recorded work sessions to suggest break intervals, durations, messages and a focus score.
class AdaptiveBreakService {
  final StorageService _storage;
  final WellnessEngine _wellnessEngine;
  final AppLogger _logger = AppLogger();

  Map<int, double> _activityPatterns = {};

  List<FocusSession> _focusSessions = [];

  int _todaySessionCount = 0;
  String _lastActiveDate = '';

  AdaptiveBreakService({
    required StorageService storage,
    required WellnessEngine wellnessEngine,
  }) : _storage = storage,
       _wellnessEngine = wellnessEngine {
    _loadActivityPatterns();
    _checkNewDay();
  }

  // Resets the daily session count on date rollover.
  void _checkNewDay() {
    final today = _getTodayString();
    if (_lastActiveDate != today) {
      _lastActiveDate = today;
      _todaySessionCount = 0;
      _loadFocusSessions();
    }
  }

  void recordWorkSession({
    required Duration duration,
    required int hourOfDay,
    required String activityLevel,
  }) {
    _checkNewDay();

    final session = FocusSession(
      date: _lastActiveDate,
      durationMinutes: duration.inMinutes,
      hourOfDay: hourOfDay,
      activityLevel: activityLevel,
      completedAt: DateTime.now(),
    );

    _focusSessions.add(session);
    _todaySessionCount++;

    _updateActivityPattern(hourOfDay, activityLevel);

    if (_focusSessions.length > 100) {
      _focusSessions = _focusSessions.sublist(_focusSessions.length - 100);
    }
    _saveFocusSessions();
    _saveActivityPatterns();

    _logger.info(
      'Work session recorded: ${duration.inMinutes}min at hour $hourOfDay',
    );
  }

  /// Busier hours give shorter intervals (about 20-60 min); long days stretch them slightly.
  int getSuggestedBreakInterval() {
    _checkNewDay();

    final currentHour = DateTime.now().hour;

    final currentActivity = _activityPatterns[currentHour] ?? 0.5;

    final dayAverage = _activityPatterns.values.isNotEmpty
        ? _activityPatterns.values.reduce((a, b) => a + b) /
              _activityPatterns.length
        : 0.5;

    final activityFactor = (currentActivity + dayAverage) / 2;

    final suggestedInterval = (60 - (activityFactor * 40)).round();

    if (_todaySessionCount > 10) {
      return (suggestedInterval * 1.2).round().clamp(20, 90);
    }

    return suggestedInterval.clamp(15, 90);
  }

  int getSuggestedBreakDuration() {
    final currentHour = DateTime.now().hour;

    if (currentHour < 12) {
      return 15;
    } else if (currentHour < 17) {
      return 20;
    } else {
      return 30;
    }
  }

  String getPersonalizedBreakMessage() {
    final currentHour = DateTime.now().hour;
    final sessionCount = _todaySessionCount;

    if (currentHour < 12) {
      return 'Great start! Keep the momentum going with a quick eye break.';
    }

    if (currentHour < 17) {
      if (sessionCount > 8) {
        return 'You\'re on fire! Time to recharge with a stretch break.';
      }
      return 'Mid-day focus detected. Time for a quick mindfulness break.';
    }

    if (sessionCount > 5) {
      return 'Productive day! Wind down with a relaxing break.';
    }
    return 'Time to refresh before finishing up.';
  }

  /// True when the current hour is historically very active and many sessions are done today.
  bool shouldDelayBreakForDeepFocus() {
    final currentHour = DateTime.now().hour;
    final currentActivity = _activityPatterns[currentHour] ?? 0.5;

    return currentActivity > 0.8 && _todaySessionCount > 5;
  }

  /// 0-100 score: rewards 25-50 min sessions and 8-12 sessions per day; 50 when no data.
  int getTodayFocusScore() {
    _checkNewDay();

    if (_focusSessions.isEmpty) return 50;

    final todaySessions = _focusSessions
        .where((s) => s.date == _lastActiveDate)
        .toList();

    if (todaySessions.isEmpty) return 50;

    final avgDuration =
        todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes) /
        todaySessions.length;

    final durationScore = (avgDuration >= 25 && avgDuration <= 50)
        ? 100
        : (avgDuration < 25 ? avgDuration * 4 : 100 - (avgDuration - 50));

    final countScore = (_todaySessionCount >= 8 && _todaySessionCount <= 12)
        ? 100
        : (_todaySessionCount < 8
              ? _todaySessionCount * 12.5
              : 100 - (_todaySessionCount - 12) * 10);

    return ((durationScore + countScore) / 2).round().clamp(0, 100);
  }

  // Exponential moving average (70/30) so recent behaviour shifts the hour profile gradually.
  void _updateActivityPattern(int hour, String activityLevel) {
    final current = _activityPatterns[hour] ?? 0.5;
    final newValue = activityLevel == 'high'
        ? 1.0
        : activityLevel == 'medium'
        ? 0.5
        : 0.2;
    _activityPatterns[hour] = (current * 0.7) + (newValue * 0.3);
  }

  void _loadActivityPatterns() {
    final dataString = _storage.getString(AppConstants.keyActivityPatterns);
    if (dataString.isEmpty) {
      for (int i = 0; i < 24; i++) {
        _activityPatterns[i] = 0.5;
      }
      return;
    }

    try {
      final Map<String, dynamic> jsonData = jsonDecode(dataString);
      _activityPatterns = jsonData.map(
        (key, value) => MapEntry(int.parse(key), (value as num).toDouble()),
      );
    } catch (e) {
      _logger.error('Failed to load activity patterns: $e');
      for (int i = 0; i < 24; i++) {
        _activityPatterns[i] = 0.5;
      }
    }
  }

  void _saveActivityPatterns() {
    final jsonData = _activityPatterns.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    _storage.setString(AppConstants.keyActivityPatterns, jsonEncode(jsonData));
  }

  void _loadFocusSessions() {
    final dataString = _storage.getString('focus_sessions');
    if (dataString.isEmpty) return;

    try {
      final List<dynamic> jsonData = jsonDecode(dataString);
      _focusSessions = jsonData
          .map((s) => FocusSession.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('Failed to load focus sessions: $e');
    }
  }

  void _saveFocusSessions() {
    final jsonData = _focusSessions.map((s) => s.toJson()).toList();
    _storage.setString('focus_sessions', jsonEncode(jsonData));
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<String> getContextualTip(BreakType type) async {
    return _wellnessEngine.getSuggestedBreakTip(type);
  }
}

/// One completed work session, persisted as JSON.
class FocusSession {
  final String date;
  final int durationMinutes;
  final int hourOfDay;
  final String activityLevel;
  final DateTime completedAt;

  FocusSession({
    required this.date,
    required this.durationMinutes,
    required this.hourOfDay,
    required this.activityLevel,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'durationMinutes': durationMinutes,
      'hourOfDay': hourOfDay,
      'activityLevel': activityLevel,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      date: json['date'] ?? '',
      durationMinutes: json['durationMinutes'] ?? 0,
      hourOfDay: json['hourOfDay'] ?? 0,
      activityLevel: json['activityLevel'] ?? 'medium',
      completedAt: DateTime.parse(json['completedAt']),
    );
  }
}
