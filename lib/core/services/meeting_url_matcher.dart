/// Recognizes a browser tab URL as a video-meeting call.
///
/// Both native bridges (`AppTrackingBridge.swift` on macOS via AppleScript,
/// `app_tracking_bridge.cpp` on Windows via UI Automation's address-bar
/// element) already resolve the active browser tab's URL for the app-usage
/// analytics feature. This reuses that existing cross-platform capability so
/// a browser-based Google Meet/Zoom-web/Teams-web call is recognized as a
/// video call, not just the native desktop apps.
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
