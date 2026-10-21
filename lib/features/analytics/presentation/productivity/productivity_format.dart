import 'package:flutter/material.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Shared formatting and colour for the Productivity screens, so a duration
/// reads the same everywhere and a category keeps one colour across the
/// timeline, the application list and the charts.

/// `6h 42m`, `48m`, `—` for nothing.
String formatDuration(int seconds) {
  if (seconds <= 0) return '—';
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// `6h 42m` written out for a screen reader.
String describeDuration(int seconds) {
  if (seconds <= 0) return 'no time';
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final parts = <String>[
    if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
    if (minutes > 0) '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
  ];
  return parts.isEmpty ? 'under a minute' : parts.join(' ');
}

/// `09:20`.
String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// `9am`, `12pm`.
String formatHour(int hour) {
  final wrapped = hour % 24;
  final suffix = wrapped < 12 ? 'am' : 'pm';
  final display = wrapped % 12 == 0 ? 12 : wrapped % 12;
  return '$display$suffix';
}

/// `Monday 20 September`.
String formatDateKey(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;

  const weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${weekdays[parsed.weekday - 1]} ${parsed.day} '
      '${months[parsed.month - 1]}';
}

/// `Mon`, for chart axes.
String shortWeekday(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return '';
  const short = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return short[parsed.weekday - 1];
}

/// A readable name for one of [AppCategorizer]'s categories.
String categoryLabel(String categoryName) {
  switch (categoryName) {
    case 'coding':
      return 'Development';
    case 'writing':
      return 'Writing';
    case 'browsing':
      return 'Browser';
    case 'meeting':
      return 'Communication';
    case 'design':
      return 'Design';
    case 'general':
      return 'Other';
    default:
      return categoryName.isEmpty ? 'Other' : categoryName;
  }
}

/// One colour per category, used wherever that category appears.
///
/// Drawn from the theme's own palette rather than invented, so the screens
/// still read correctly when the user changes theme.
Color categoryColor(String categoryName) {
  switch (categoryName) {
    case 'coding':
      return AppTheme.accent;
    case 'writing':
      return AppTheme.info;
    case 'browsing':
      return AppTheme.warning;
    case 'meeting':
      return AppTheme.longBreak;
    case 'design':
      return AppTheme.shortBreak;
    default:
      return AppTheme.gray500;
  }
}

/// The colour a stretch of the timeline is drawn in.
///
/// Idle and breaks are deliberately quiet: they are context for the work, not
/// competing with it.
Color activityColor(ActivityKind kind, String categoryName) {
  switch (kind) {
    case ActivityKind.active:
      return categoryColor(categoryName);
    case ActivityKind.onBreak:
      return AppTheme.success;
    case ActivityKind.idle:
      return AppTheme.gray700;
  }
}

String activityLabel(ActivityKind kind) {
  switch (kind) {
    case ActivityKind.active:
      return 'Active';
    case ActivityKind.onBreak:
      return 'Break';
    case ActivityKind.idle:
      return 'Idle';
  }
}
