import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/meeting_url_matcher.dart';

void main() {
  group('MeetingUrlMatcher', () {
    test('recognizes known meeting URLs', () {
      const meetingUrls = [
        'https://meet.google.com/abc-defg-hij',
        'https://us04web.zoom.us/j/1234567890',
        'https://zoom.us/wc/1234567890/join',
        'https://teams.microsoft.com/l/meetup-join/xyz',
        'https://acme.webex.com/meet/room',
        'https://whereby.com/my-room',
        'https://global.gotomeeting.com/join/123456789',
        'https://bluejeans.com/123456789',
        'https://meet.jit.si/SomeRoomName',
      ];
      for (final url in meetingUrls) {
        expect(MeetingUrlMatcher.isMeetingUrl(url), isTrue, reason: url);
      }
    });

    test('is case-insensitive', () {
      expect(
        MeetingUrlMatcher.isMeetingUrl('https://MEET.GOOGLE.COM/abc-defg-hij'),
        isTrue,
      );
    });

    test('rejects non-meeting URLs', () {
      const nonMeetingUrls = [
        'https://www.google.com/search?q=cats',
        'https://github.com/bijithpn/standup',
        'https://mail.google.com/mail/u/0/',
        '',
      ];
      for (final url in nonMeetingUrls) {
        expect(MeetingUrlMatcher.isMeetingUrl(url), isFalse, reason: url);
      }
    });

    test('rejects null', () {
      expect(MeetingUrlMatcher.isMeetingUrl(null), isFalse);
    });
  });
}
