/// Whether a quick reminder (posture / eye rest / meeting-ready) may take
/// over the whole screen as a full poster, or must stay a small
/// low-opacity pill instead. Mirrors `TimerContextManager.isMeetingActive`
/// and `.isPresentationActive`'s exact inputs — duplicated here (rather
/// than calling that class directly) because the overlay window doesn't
/// hold its own `TimerContextManager`, only the lower-level detection
/// services it wraps.
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
