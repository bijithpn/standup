// Guards the consolidation of duplicated settings: each preference has one
// authoritative place to change it. These scan the source so a future screen
// cannot quietly reintroduce a second owner.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('only the Calendar Sync controller writes calendarEnabled', () {
    final writers = <String>[];
    final pattern = RegExp(r'copyWith\([^;]*calendarEnabled\s*:');
    for (final f in dartFiles('lib')) {
      if (f.path.endsWith('settings_model.dart')) continue;
      if (f.path.endsWith('calendar_sync_controller.dart')) continue;
      if (pattern.hasMatch(f.readAsStringSync())) writers.add(f.path);
    }
    expect(
      writers,
      isEmpty,
      reason: 'second owner of calendarEnabled: $writers',
    );
  });

  test('only the Calendar Sync controller writes detectMeetings', () {
    final writers = <String>[];
    final pattern = RegExp(r'copyWith\([^;]*detectMeetings\s*:');
    for (final f in dartFiles('lib')) {
      if (f.path.endsWith('settings_model.dart')) continue;
      if (f.path.endsWith('calendar_sync_controller.dart')) continue;
      if (pattern.hasMatch(f.readAsStringSync())) writers.add(f.path);
    }
    expect(
      writers,
      isEmpty,
      reason: 'second owner of detectMeetings: $writers',
    );
  });

  test('exactly one screen requests calendar permission', () {
    final callers = <String>[];
    for (final f in dartFiles('lib')) {
      if (f.path.contains('calendar_sync_controller.dart') ||
          f.path.contains('calendar_permission_service.dart') ||
          f.path.contains('calendar_service.dart') ||
          f.path.contains('/native/') ||
          f.path.contains('notification_service.dart')) {
        continue;
      }
      final text = f.readAsStringSync();
      if (text.contains('requestPermission()') ||
          text.contains('requestPermissions()')) {
        callers.add(f.path);
      }
    }
    expect(
      callers,
      isEmpty,
      reason: 'permission requested outside controller: $callers',
    );
  });

  test('no Exercises or articles screen is left behind', () {
    expect(
      File(
        'lib/features/settings/presentation/sections/exercises_section.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'lib/features/wellness/presentation/wellness_articles_page.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('main navigation has a single Calendar Sync entry and no Exercises', () {
    final layout = File('lib/app/main_layout.dart').readAsStringSync();
    expect("section: 'Calendar Sync',".allMatches(layout).length, 1);
    expect("section: 'Exercises'".allMatches(layout).length, 0);
    // Old deep links still resolve.
    expect(layout, contains("'Exercises': 'Breaks & Profiles'"));
    expect(layout, isNot(contains("section: 'Wellness Library'")));
  });
}
