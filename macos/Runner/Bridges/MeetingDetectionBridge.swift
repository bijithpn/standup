import Cocoa
import FlutterMacOS

class MeetingDetectionBridge: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    // Known meeting app bundle IDs
    private let knownMeetingApps = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.google.Chrome.app.Default", // Fallback for browser-based (Meet, etc)
        "com.tinyspeck.slackmacgap",
        "com.cisco.webexmeetingsapp"
    ]

    init(registrar: FlutterPluginRegistrar) {
        super.init()
        let channel = FlutterEventChannel(name: "com.standup/meeting_detection", binaryMessenger: registrar.messenger)
        channel.setStreamHandler(self)
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleAppActivation(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }
        
        let isMeeting = knownMeetingApps.contains(bundleId)
        eventSink?(["isMeetingAppFrontmost": isMeeting, "bundleId": bundleId])
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontmost.bundleIdentifier {
            events(["isMeetingAppFrontmost": knownMeetingApps.contains(bundleId), "bundleId": bundleId])
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
