import Cocoa
import FlutterMacOS

class FocusModeBridge: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    init(registrar: FlutterPluginRegistrar) {
        super.init()
        let channel = FlutterEventChannel(name: "com.breakmate/focus_mode", binaryMessenger: registrar.messenger)
        channel.setStreamHandler(self)
        
        // Best-effort DND detection via DistributedNotificationCenter
#if !APP_STORE
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(checkFocusMode),
            name: NSNotification.Name("com.apple.notificationcenterui.dndprefs_changed"),
            object: nil
        )
#endif
    }

    deinit {
#if !APP_STORE
        DistributedNotificationCenter.default().removeObserver(self)
#endif
    }

    @objc private func checkFocusMode() {
        let dndEnabled = UserDefaults(suiteName: "com.apple.notificationcenterui")?.bool(forKey: "doNotDisturb") ?? false
        eventSink?(dndEnabled)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        checkFocusMode()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
