import Cocoa
import FlutterMacOS

class AppTrackingBridge: NSObject {
    private let channel: FlutterMethodChannel
    
    init(registrar: FlutterPluginRegistrar) {
        self.channel = FlutterMethodChannel(
            name: "com.breakmate/app_tracking",
            binaryMessenger: registrar.messenger
        )
        super.init()
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "getActiveApp":
                self?.handleGetActiveApp(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func handleGetActiveApp(result: FlutterResult) {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            let appInfo: [String: Any] = [
                "name": frontmostApp.localizedName ?? "Unknown",
                "bundleId": frontmostApp.bundleIdentifier ?? "Unknown",
                "executableName": frontmostApp.executableURL?.lastPathComponent ?? "Unknown"
            ]
            result(appInfo)
        } else {
            result(nil)
        }
    }
}
