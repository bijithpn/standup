import Cocoa
import FlutterMacOS

class DisplayBridgeManager: NSObject, FlutterStreamHandler {
    static let shared = DisplayBridgeManager()
    
    private var eventSink: FlutterEventSink?
    
    func register(with binaryMessenger: FlutterBinaryMessenger) {
        let methodChannel = FlutterMethodChannel(name: "com.standup/display_bridge", binaryMessenger: binaryMessenger)
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getDisplays":
                result(self?.getDisplays())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        let eventChannel = FlutterEventChannel(name: "com.standup/display_events", binaryMessenger: binaryMessenger)
        eventChannel.setStreamHandler(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    @objc private func screenParametersChanged() {
        if let sink = eventSink {
            sink(["type": "display_changed"])
        }
    }
    
    private func getDisplays() -> [[String: Any]] {
        var displays = [[String: Any]]()
        
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let isPrimary = index == 0 // Usually the primary screen is the first one
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            
            // Generate a persistent ID based on display device UUID if possible, but NSScreen doesn't expose it easily.
            // Using localizedName as ID for simplicity, or simply an index string
            var displayId = "Display_\(index)"
            if #available(macOS 10.15, *) {
                displayId = screen.localizedName
            }
            
            let displayData: [String: Any] = [
                "id": displayId,
                "isPrimary": isPrimary,
                "width": frame.width,
                "height": frame.height,
                "pixelRatio": screen.backingScaleFactor,
                "boundsX": frame.origin.x,
                "boundsY": frame.origin.y,
                "boundsWidth": frame.width,
                "boundsHeight": frame.height,
                "workAreaX": visibleFrame.origin.x,
                "workAreaY": visibleFrame.origin.y,
                "workAreaWidth": visibleFrame.width,
                "workAreaHeight": visibleFrame.height,
                "refreshRate": 60.0 // macOS refresh rate is tricky without CGDisplayMode, 60 is a safe default
            ]
            displays.append(displayData)
        }
        
        return displays
    }
}
