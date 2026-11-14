import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/settings/backup_service.dart';

void main() {
  test('preview summarises a backup before it is restored', () {
    final p = BackupService.preview({
      'timestamp': '2026-11-14T09:30:00',
      'settings': {'a': 1},
      'daily_stats': [
        {'breaksCompleted': 4},
        {'breaksCompleted': 6},
      ],
    });
    expect(p.statDays, 2);
    expect(p.breaksCompleted, 10);
    expect(p.hasSettings, isTrue);
    expect(p.savedAt, DateTime(2026, 11, 14, 9, 30));
  });

  test('parse rejects files that are not backups', () {
    expect(() => BackupService.parse('{"x":1}'), throwsA(anything));
    expect(BackupService.parse('{"timestamp":"t"}'), isA<Map>());
  });
}
