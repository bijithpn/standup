import Cocoa
import FlutterMacOS

/// Focus Mode / Do Not Disturb detector leveraging macOS DistributedNotificationCenter
/// and system defaults, matching DeskRest's implementation safely without TCC crashes.
class FocusModeBridge: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var periodicTimer: Timer?

    init(registrar: FlutterPluginRegistrar) {
        super.init()
        let channel = FlutterEventChannel(name: "com.breakmate/focus_mode", binaryMessenger: registrar.messenger)
        channel.setStreamHandler(self)
        
        setupFocusMonitoring()
    }

    private func setupFocusMonitoring() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self,
            selector: #selector(checkFocusMode),
            name: NSNotification.Name("com.apple.controlcenter.focus.changed"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(checkFocusMode),
            name: NSNotification.Name("com.apple.donotdisturb.state.changed"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(checkFocusMode),
            name: NSNotification.Name("com.apple.notificationcenterui.dndprefs_changed"),
            object: nil
        )
        
        // Periodic check to catch mode toggles even if notifications are filtered
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkFocusMode()
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        periodicTimer?.invalidate()
        periodicTimer = nil
    }

    @objc private func checkFocusMode() {
        let isFocused = UserDefaults(suiteName: "com.apple.notificationcenterui")?.bool(forKey: "doNotDisturb") ?? false
        
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(isFocused)
        }
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
