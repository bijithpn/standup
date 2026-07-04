import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:clock/clock.dart';

void main() {
  test('Fake async overrides DateTime.now()?', () {
    fakeAsync((async) {
      final start = clock.now();
      async.elapse(const Duration(seconds: 1));
      final end = clock.now();
      expect(end.difference(start), equals(const Duration(seconds: 1)));
    });
  });
}
