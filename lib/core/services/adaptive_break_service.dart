import 'dart:convert';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/services/storage_service.dart';
import 'package:standup/core/utils/logger.dart';

/// Adaptive break timing service that learns from user activity patterns
/// and suggests optimal break times based on historical data
class AdaptiveBreakService {
  final StorageService _storage;
  final AppLogger _logger = AppLogger();

  // Activity patterns: hour of day -> activity level (0-10)
  Map<int, double> _activityPatterns = {};
  
  // Focus session history
  List<FocusSession> _focusSessions = [];
  
  // Current day's sessions
  int _todaySessionCount = 0;
  String _lastActiveDate = '';

  AdaptiveBreakService({required StorageService storage}) : _storage = storage {
    _loadActivityPatterns();
    _checkNewDay();
  }

  /// Check if we're on a new day and reset daily counters
  void _checkNewDay() {
    final today = _getTodayString();
    if (_lastActiveDate != today) {
      _lastActiveDate = today;
      _todaySessionCount = 0;
      _loadFocusSessions();
    }
  }

  /// Record a completed work session
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
    
    // Update activity pattern for this hour
    _updateActivityPattern(hourOfDay, activityLevel);
    
    // Save sessions (keep last 100)
    if (_focusSessions.length > 100) {
      _focusSessions = _focusSessions.sublist(_focusSessions.length - 100);
    }
    _saveFocusSessions();
    _saveActivityPatterns();
    
    _logger.info('Work session recorded: ${duration.inMinutes}min at hour $hourOfDay');
  }

  /// Get suggested break interval based on current time and historical patterns
  int getSuggestedBreakInterval() {
    _checkNewDay();
    
    final currentHour = DateTime.now().hour;
    
    // Get activity level for current hour
    final currentActivity = _activityPatterns[currentHour] ?? 0.5;
    
    // Get average activity for the day so far
    final dayAverage = _activityPatterns.values.isNotEmpty
        ? _activityPatterns.values.reduce((a, b) => a + b) / _activityPatterns.length
        : 0.5;
    
    // Calculate suggested interval
    // Higher activity = shorter intervals (more frequent breaks)
    // Lower activity = longer intervals (fewer interruptions)
    final activityFactor = (currentActivity + dayAverage) / 2;
    
    // Base interval: 20-60 minutes based on activity
    // activityFactor 0.0 -> 60 min, 1.0 -> 20 min
    final suggestedInterval = (60 - (activityFactor * 40)).round();
    
    // Adjust based on number of sessions today
    // More sessions = slightly longer intervals to prevent burnout
    if (_todaySessionCount > 10) {
      return (suggestedInterval * 1.2).round().clamp(20, 90);
    }
    
    return suggestedInterval.clamp(15, 90);
  }

  /// Get suggested break duration based on session length and time of day
  int getSuggestedBreakDuration() {
    final currentHour = DateTime.now().hour;
    
    // Morning (before 12): shorter breaks to maintain momentum
    // Afternoon (12-17): standard breaks
    // Evening (after 17): longer breaks for recovery
    
    if (currentHour < 12) {
      return 15; // 15 seconds micro break
    } else if (currentHour < 17) {
      return 20; // 20 seconds standard
    } else {
      return 30; // 30 seconds for evening recovery
    }
  }

  /// Get personalized break message based on current session
  String getPersonalizedBreakMessage() {
    final currentHour = DateTime.now().hour;
    final sessionCount = _todaySessionCount;
    
    // Morning messages
    if (currentHour < 12) {
      return 'Great start! Keep the momentum going with a quick eye break.';
    }
    
    // Afternoon messages
    if (currentHour < 17) {
      if (sessionCount > 8) {
        return 'You\'re on fire! Time to recharge with a stretch break.';
      }
      return 'Mid-day focus detected. Time for a quick mindfulness break.';
    }
    
    // Evening messages
    if (sessionCount > 5) {
      return 'Productive day! Wind down with a relaxing break.';
    }
    return 'Time to refresh before finishing up.';
  }

  /// Check if user is in a deep focus session and should delay break
  bool shouldDelayBreakForDeepFocus() {
    final currentHour = DateTime.now().hour;
    final currentActivity = _activityPatterns[currentHour] ?? 0.5;
    
    // If current hour typically has very high focus (activity > 0.8)
    // and we've had multiple sessions today, consider delaying
    return currentActivity > 0.8 && _todaySessionCount > 5;
  }

  /// Get focus quality score for today (0-100)
  int getTodayFocusScore() {
    _checkNewDay();
    
    if (_focusSessions.isEmpty) return 50;
    
    final todaySessions = _focusSessions
        .where((s) => s.date == _lastActiveDate)
        .toList();
    
    if (todaySessions.isEmpty) return 50;
    
    // Calculate score based on:
    // - Session completion rate
    // - Average session duration
    // - Consistency
    
    final avgDuration = todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes) / todaySessions.length;
    
    // Ideal session: 25-50 minutes
    final durationScore = (avgDuration >= 25 && avgDuration <= 50) ? 100 : 
                          (avgDuration < 25 ? avgDuration * 4 : 100 - (avgDuration - 50));
    
    // Session count score: 8-12 sessions is ideal
    final countScore = (_todaySessionCount >= 8 && _todaySessionCount <= 12) ? 100 :
                       (_todaySessionCount < 8 ? _todaySessionCount * 12.5 : 100 - (_todaySessionCount - 12) * 10);
    
    return ((durationScore + countScore) / 2).round().clamp(0, 100);
  }

  // ============ Private Helper Methods ============

  void _updateActivityPattern(int hour, String activityLevel) {
    final current = _activityPatterns[hour] ?? 0.5;
    // Smooth update: 70% old, 30% new
    final newValue = activityLevel == 'high' ? 1.0 : 
                     activityLevel == 'medium' ? 0.5 : 0.2;
    _activityPatterns[hour] = (current * 0.7) + (newValue * 0.3);
  }

  void _loadActivityPatterns() {
    final dataString = _storage.getString(AppConstants.keyActivityPatterns);
    if (dataString.isEmpty) {
      // Initialize with neutral values
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
    // Load from storage if needed
    // For now, we just reset daily
  }

  void _saveFocusSessions() {
    // Save last 100 sessions
    final jsonData = _focusSessions.map((s) => s.toJson()).toList();
    _storage.setString('focus_sessions', jsonEncode(jsonData));
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// Focus session record
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
