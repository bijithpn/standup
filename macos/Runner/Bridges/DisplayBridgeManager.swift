import Cocoa
import FlutterMacOS

class DisplayBridgeManager: NSObject, FlutterStreamHandler {
    static let shared = DisplayBridgeManager()
    
    private var eventSink: FlutterEventSink?
    
    func register(with binaryMessenger: FlutterBinaryMessenger) {
        let methodChannel = FlutterMethodChannel(name: "com.breakmate/display_bridge", binaryMessenger: binaryMessenger)
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getDisplays":
                result(self?.getDisplays())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        let eventChannel = FlutterEventChannel(name: "com.breakmate/display_events", binaryMessenger: binaryMessenger)
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
            // Dart re-enumerates displays after this signal so native and
            // Flutter use the same payload shape for initial and changed state.
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
            
            var displayId = "Display_\(index)"
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                let displayID = CGDirectDisplayID(screenNumber.uint32Value)
                if let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID) {
                    let uuidString = CFUUIDCreateString(nil, uuidRef.takeRetainedValue()) as String?
                    if let uuid = uuidString {
                        displayId = uuid
                    } else {
                        displayId = String(displayID)
                    }
                } else {
                    displayId = String(displayID)
                }
            } else if #available(macOS 10.15, *) {
                displayId = screen.localizedName
            }
            
            let primaryHeight = screens.first?.frame.height ?? 0
            let displayData: [String: Any] = [
                "id": displayId,
                "isPrimary": isPrimary,
                "width": frame.width,
                "height": frame.height,
                "pixelRatio": screen.backingScaleFactor,
                "boundsX": frame.origin.x,
                "boundsY": primaryHeight - frame.origin.y - frame.height,
                "boundsWidth": frame.width,
                "boundsHeight": frame.height,
                "workAreaX": visibleFrame.origin.x,
                "workAreaY": primaryHeight - visibleFrame.origin.y - visibleFrame.height,
                "workAreaWidth": visibleFrame.width,
                "workAreaHeight": visibleFrame.height,
                "refreshRate": 60.0 // macOS refresh rate is tricky without CGDisplayMode, 60 is a safe default
            ]
            displays.append(displayData)
        }
        
        return displays
    }
}
