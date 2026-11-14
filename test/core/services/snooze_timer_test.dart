import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/snooze_timer.dart';

void main() {
  test('replacing a snooze cannot resume the new pause early', () {
    fakeAsync((async) {
      final snooze = SnoozeTimer();
      var resumes = 0;
      snooze.start(const Duration(minutes: 2), () => resumes++);
      async.elapse(const Duration(minutes: 1));
      snooze.start(const Duration(minutes: 5), () => resumes++);
      async.elapse(const Duration(minutes: 1));
      expect(resumes, 0);
      async.elapse(const Duration(minutes: 4));
      expect(resumes, 1);
      expect(snooze.resumeAt, isNull);
    });
  });
  test('manual cancellation removes the pending resume', () {
    fakeAsync((async) {
      final snooze = SnoozeTimer();
      var resumed = false;
      snooze.start(const Duration(minutes: 2), () => resumed = true);
      snooze.cancel();
      async.elapse(const Duration(minutes: 10));
      expect(resumed, isFalse);
      expect(snooze.resumeAt, isNull);
    });
  });
  test('meeting snooze preserves seconds until the exact end', () {
    fakeAsync((async) {
      final snooze = SnoozeTimer();
      var resumed = false;
      snooze.start(
        const Duration(minutes: 2, seconds: 45),
        () => resumed = true,
      );
      async.elapse(const Duration(minutes: 2, seconds: 44));
      expect(resumed, isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(resumed, isTrue);
    });
  });
}
