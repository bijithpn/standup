/// Detects meeting URLs in browser tabs (substring match); used where bundle id alone cannot tell a call from normal browsing.
abstract final class MeetingUrlMatcher {
  static const _patterns = [
    'meet.google.com',
    'zoom.us/j/',
    'zoom.us/wc',
    'zoom.us/s/',
    'teams.microsoft.com',
    'teams.live.com',
    'webex.com',
    'whereby.com',
    'gotomeeting.com',
    'bluejeans.com',
    'meet.jit.si',
    'chime.aws',
  ];

  static bool isMeetingUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return _patterns.any(lower.contains);
  }
}
