import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_gate.dart';

void main() {
  test(
    'allows the poster when nothing meeting/presentation-like is active',
    () {
      expect(
        allowFullPosterReminder(
          detectMeetings: true,
          calendarMeetingActive: false,
          detectVideoCalls: true,
          videoCallActive: false,
          presenting: false,
        ),
        isTrue,
      );
    },
  );

  test('blocks the poster during a detected calendar meeting', () {
    expect(
      allowFullPosterReminder(
        detectMeetings: true,
        calendarMeetingActive: true,
        detectVideoCalls: true,
        videoCallActive: false,
        presenting: false,
      ),
      isFalse,
    );
  });

  test('blocks the poster during a detected video call', () {
    expect(
      allowFullPosterReminder(
        detectMeetings: true,
        calendarMeetingActive: false,
        detectVideoCalls: true,
        videoCallActive: true,
        presenting: false,
      ),
      isFalse,
    );
  });

  test('blocks the poster while presenting', () {
    expect(
      allowFullPosterReminder(
        detectMeetings: true,
        calendarMeetingActive: false,
        detectVideoCalls: true,
        videoCallActive: false,
        presenting: true,
      ),
      isFalse,
    );
  });

  test('ignores meeting/video-call detection when the user disabled it', () {
    expect(
      allowFullPosterReminder(
        detectMeetings: false,
        calendarMeetingActive: true,
        detectVideoCalls: false,
        videoCallActive: true,
        presenting: false,
      ),
      isTrue,
    );
  });
}
