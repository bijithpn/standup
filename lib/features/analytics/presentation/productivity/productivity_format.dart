import 'package:flutter/material.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

String formatDuration(int seconds) {
  if (seconds <= 0) return '—';
  if (seconds < 60) return '${seconds}s';
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

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

String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String formatHour(int hour) {
  final wrapped = hour % 24;
  final suffix = wrapped < 12 ? 'am' : 'pm';
  final display = wrapped % 12 == 0 ? 12 : wrapped % 12;
  return '$display$suffix';
}

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

String shortWeekday(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return '';
  const short = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return short[parsed.weekday - 1];
}

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

const List<Color> _appPalette = <Color>[
  Color(0xFF38BDF8),
  Color(0xFFF59E0B),
  Color(0xFF34D399),
  Color(0xFFA78BFA),
  Color(0xFFF472B6),
  Color(0xFFFB923C),
  Color(0xFF2DD4BF),
  Color(0xFFFB7185),
  Color(0xFFA3E635),
  Color(0xFF818CF8),
];

/// Distinct colour per ranked application so the donut, list and detail sheet agree.
Color appColor(int rank) => _appPalette[rank % _appPalette.length];

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

// Idle and break get fixed colours; active uses the category colour.
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
