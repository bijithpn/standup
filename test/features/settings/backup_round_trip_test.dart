import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:objectbox/objectbox.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/settings/backup_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import '../../core/services/timer_engine_test.dart' show FakeStorageService;

class _SegmentBox extends Mock implements Box<ActivitySegment> {}

class _KvBox extends Mock implements Box<KeyValueRecord> {}

class _SettingsBox extends Mock implements Box<SettingsSnapshot> {}

class _CompanionBox extends Mock implements Box<CompanionPreferences> {}

class _Snapshot extends Fake implements SettingsSnapshot {}

class _Companion extends Fake implements CompanionPreferences {}

/// Key-value reads and the kv box share one map, as in the real storage.
class _Storage extends FakeStorageService {
  final Map<String, KeyValueRecord> records = {};

  void _write(String key, Object value, String type) =>
      records[key] = KeyValueRecord(key: key, value: '$value', type: type);

  @override
  Future<bool> setString(String key, String value) async {
    _write(key, value, 'string');
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _write(key, value, 'int');
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _write(key, value, 'bool');
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _write(key, value, 'double');
    return true;
  }

  @override
  String getString(String key, {String defaultValue = ''}) =>
      records[key]?.value ?? defaultValue;

  @override
  int getInt(String key, {int defaultValue = 0}) =>
      int.tryParse(records[key]?.value ?? '') ?? defaultValue;

  @override
  bool getBool(String key, {bool defaultValue = false}) =>
      records.containsKey(key) ? records[key]!.value == 'true' : defaultValue;

  @override
  double getDouble(String key, {double defaultValue = 0.0}) =>
      double.tryParse(records[key]?.value ?? '') ?? defaultValue;
}

ActivitySegment _segment(String app) => ActivitySegment(
  appKey: app,
  appName: app,
  date: '2026-11-27',
  startedAtMs: 1000,
  endedAtMs: 61000,
);

class _Device {
  _Device([List<ActivitySegment> initial = const []]) {
    segments.addAll(initial);

    final segmentBox = _SegmentBox();
    when(segmentBox.getAll).thenAnswer((_) => [...segments]);
    when(segmentBox.removeAll).thenAnswer((_) {
      segments.clear();
      return 0;
    });
    when(() => segmentBox.putMany(any())).thenAnswer((call) {
      if (failures > 0) {
        failures--;
        throw StateError('disk full');
      }
      segments.addAll(call.positionalArguments.single as List<ActivitySegment>);
      return <int>[];
    });

    final kv = _KvBox();
    when(kv.getAll).thenAnswer((_) => [...storage.records.values]);
    when(kv.removeAll).thenAnswer((_) {
      storage.records.clear();
      return 0;
    });
    when(() => kv.put(any())).thenAnswer((call) {
      final record = call.positionalArguments.single as KeyValueRecord;
      storage.records[record.key] = record;
      return 1;
    });

    SettingsSnapshot? snapshot;
    final settingsBox = _SettingsBox();
    when(() => settingsBox.put(any())).thenAnswer((call) {
      snapshot = call.positionalArguments.single as SettingsSnapshot;
      return 1;
    });
    when(() => settingsBox.get(any())).thenAnswer((_) => snapshot);

    CompanionPreferences? companion;
    final companionBox = _CompanionBox();
    when(() => companionBox.put(any())).thenAnswer((call) {
      companion = call.positionalArguments.single as CompanionPreferences;
      return 1;
    });
    when(() => companionBox.get(any())).thenAnswer((_) => companion);

    storage
      ..activitySegmentBox = segmentBox
      ..kvBox = kv
      ..settingsBox = settingsBox
      ..companionPreferencesBox = companionBox;
    repository = SettingsRepository(storage: storage);
  }

  final _Storage storage = _Storage();
  final List<ActivitySegment> segments = [];
  int failures = 0;
  late final SettingsRepository repository;

  BackupService use() {
    if (sl.isRegistered<SettingsRepository>()) {
      sl.unregister<SettingsRepository>();
    }
    sl.registerSingleton<SettingsRepository>(repository);
    return BackupService(storage);
  }
}

Map<String, dynamic> _file(BackupService service) =>
    BackupService.parse(jsonEncode(service.build()));

void main() {
  setUpAll(() {
    registerFallbackValue(KeyValueRecord(key: '', value: '', type: 'string'));
    registerFallbackValue(_Snapshot());
    registerFallbackValue(_Companion());
  });
  tearDown(() async {
    SimplePrefs.instance.clear();
    await sl.reset();
  });

  test('a backup overwrites every setting on another device', () async {
    final source = _Device([_segment('code')]);
    final exporter = source.use();
    await source.repository.save(
      source.repository.currentSettings.copyWith(
        shortBreakIntervalMinutes: 33,
        strictMode: true,
        companionPetName: 'Biscuit',
        companionWanderingEnabled: false,
        companionKeepOnScreen: false,
        companionAvatarDefinition: '{"id":"goose"}',
      ),
    );
    await source.storage.setString(
      AppConstants.keyWeeklyStats,
      jsonEncode([
        {'date': '2026-11-27', 'breaksCompleted': 4, 'usageMinutes': 90},
      ]),
    );
    SimplePrefs.instance.setInt('daily_skip_limit', 2);
    final file = _file(exporter);
    expect(BackupService.preview(file).breaksCompleted, 4);

    SimplePrefs.instance.clear();
    final target = _Device([_segment('old')]);
    final importer = target.use();
    await target.repository.save(target.repository.currentSettings);
    await target.storage.setString('only_on_target', 'stale');

    expect(await importer.restore(file), isEmpty);
    expect(
      target.repository.currentSettings.toMap(),
      source.repository.currentSettings.toMap(),
    );
    expect(target.segments.single.appKey, 'code');
    expect(target.storage.records, isNot(contains('only_on_target')));
    expect(SimplePrefs.instance.getInt('daily_skip_limit'), 2);
  });

  test('reloads services that cache data in memory', () async {
    final device = _Device();
    final service = device.use();
    final history = BreakHistoryService(storage: device.storage);
    sl.registerSingleton<BreakHistoryService>(history);
    final file = _file(service);
    (file['kv_records'] as List).add({
      'key': AppConstants.keyBreakHistoryData,
      'type': 'string',
      'value': jsonEncode([
        {'time': DateTime.now().toIso8601String(), 'completed': true},
      ]),
    });

    await service.restore(file);

    expect(history.events, hasLength(1));
  });

  test(
    'reports everything it cannot import and keeps current values',
    () async {
      final device = _Device([_segment('old')]);
      final service = device.use();
      final file = _file(service);
      final settings = Map<String, dynamic>.from(file['settings'] as Map)
        ..['shortBreakIntervalMinutes'] = 'soon'
        ..['soundscape'] = 'whale_song'
        ..['hologramMode'] = true
        ..remove('strictMode')
        ..['officeHours'] = 6;
      file
        ..['settings'] = settings
        ..['activity_segments'] = ['broken', _segment('code').toMap()]
        ..remove('preferences');

      final report = (await service.restore(file)).join('\n');

      expect(report, contains('so yours stay: short break interval minutes.'));
      expect(report, contains("couldn't be updated: soundscape."));
      expect(report, contains('hologram mode'));
      expect(report, contains('strict mode'));
      expect(report, contains('1 activity entries are damaged'));
      expect(report, contains("Skip limits"));
      expect(device.repository.currentSettings.officeHours, 6);
      expect(device.repository.currentSettings.shortBreakIntervalMinutes, 20);
      expect(device.segments.single.appKey, 'code');
    },
  );

  test('an older backup keeps the data it does not contain', () async {
    final device = _Device([_segment('old')]);
    final report = await device.use().restore({'timestamp': '2026-11-01'});
    expect(device.segments.single.appKey, 'old');
    expect(report.join(), contains("Activity history isn't in this file"));
  });

  test('refuses a newer or damaged file without changing anything', () async {
    final device = _Device([_segment('old')]);
    final service = device.use();
    for (final bad in <Map<String, dynamic>>[
      {'timestamp': 't', 'schemaVersion': 99, 'activity_segments': []},
      {'timestamp': 't', 'activity_segments': 'nope'},
    ]) {
      await expectLater(service.restore(bad), throwsA(isA<AppException>()));
    }
    expect(device.segments.single.appKey, 'old');
    expect(() => BackupService.parse('not json'), throwsA(isA<AppException>()));
  });

  test('puts the previous data back when writing fails', () async {
    final device = _Device([_segment('old')]);
    final service = device.use();
    await device.repository.save(device.repository.currentSettings);
    final file = _file(service)
      ..['activity_segments'] = [_segment('code').toMap()];
    (file['settings'] as Map)['officeHours'] = 6;
    device.failures = 1;

    await expectLater(
      service.restore(file),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('previous data is unchanged'),
        ),
      ),
    );
    expect(device.segments.single.appKey, 'old');
    expect(device.repository.currentSettings.officeHours, 8);
  });

  test('CSV import lists the rows it cannot read', () {
    final table = BackupService.parseStatsTable(
      'Date,BreaksCompleted,BreaksSkipped,UsageMinutes\n'
      '2026-11-27,4,1,90\n'
      '2026-11-26,four,0,10\n'
      'yesterday,1,0,10\n',
    );
    expect(table.rows.single.breaksCompleted, 4);
    expect(table.skipped, [3, 4]);
    expect(
      () => BackupService.parseStatsTable('Time,Type,Detail\n'),
      throwsA(isA<AppException>()),
    );
  });
}
