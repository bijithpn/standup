import Cocoa
import FlutterMacOS

class OverlayWindowBridge: NSObject {
    private let channel: FlutterMethodChannel

    init(registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: "com.breakmate/overlay", binaryMessenger: registrar.messenger)
        super.init()
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "setStrictMode":
                let enabled = call.arguments as? Bool ?? false
                self?.setStrictMode(enabled)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setStrictMode(_ enabled: Bool) {
        guard let window = NSApp.windows.first else { return }
        if enabled {
            window.level = .screenSaver 
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        } else {
            window.level = .normal
            window.collectionBehavior = []
        }
    }
}
