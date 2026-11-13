/// The full-screen poster is only allowed when no meeting (calendar or video call) is active and the user is not presenting.
bool allowFullPosterReminder({
  required bool detectMeetings,
  required bool calendarMeetingActive,
  required bool detectVideoCalls,
  required bool videoCallActive,
  required bool presenting,
}) {
  final meetingActive =
      (detectMeetings && calendarMeetingActive) ||
      (detectVideoCalls && videoCallActive);
  return !meetingActive && !presenting;
}
