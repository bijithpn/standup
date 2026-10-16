import Cocoa
import FlutterMacOS
import Intents

/// Modern Focus Mode / Do Not Disturb detector leveraging Apple's Intents framework
/// (INFocusStatusCenter) on macOS 12+, matching DeskRest's implementation.
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
        if #available(macOS 12.0, *) {
            INFocusStatusCenter.default.requestAuthorization { [weak self] _ in
                DispatchQueue.main.async {
                    self?.checkFocusMode()
                }
            }
        }
        
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
        var isFocused = false
        if #available(macOS 12.0, *) {
            isFocused = INFocusStatusCenter.default.focusStatus.isFocused ?? false
        } else {
            isFocused = UserDefaults(suiteName: "com.apple.notificationcenterui")?.bool(forKey: "doNotDisturb") ?? false
        }
        
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
