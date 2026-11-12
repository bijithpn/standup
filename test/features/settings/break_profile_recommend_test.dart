import 'package:breakmate/features/settings/break_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommend maps work style and hours to a preset', () {
    String id(String w, int h) => BreakProfile.recommend(work: w, hours: h).id;
    expect(id('coding', 6), 'developer');
    expect(id('meetings', 6), 'health');
    expect(id('study', 4), 'pomodoro');
    expect(id('creative', 6), 'deep_work');
    expect(id('creative', 9), 'developer');
  });
}
