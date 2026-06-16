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
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            result(nil)
            return
        }
        
        let appName = frontmostApp.localizedName ?? "Unknown"
        let bundleId = frontmostApp.bundleIdentifier ?? "Unknown"
        let exeName = frontmostApp.executableURL?.lastPathComponent ?? "Unknown"
        
        var displayName = appName
        // If accessibility permissions are available, read the active window title.
        if let windowTitle = getActiveWindowTitle(pid: frontmostApp.processIdentifier) {
            displayName = windowTitle
        }
        
        var appInfo: [String: Any] = [
            "name": displayName,
            "bundleId": bundleId,
            "executableName": exeName
        ]
        
        if let url = getBrowserUrl(appName: appName) {
            appInfo["url"] = url
        }
        
        result(appInfo)
    }
    
    private func getActiveWindowTitle(pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        
        let appRef = AXUIElementCreateApplication(pid)
        var windowRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef)
        
        guard result == .success, let window = windowRef else { return nil }
        
        var titleRef: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
        
        if titleResult == .success, let title = titleRef as? String {
            return title
        }
        
        return nil
    }
    
    private func getBrowserUrl(appName: String) -> String? {
        let scriptSource: String
        if appName.contains("Safari") {
            scriptSource = "tell application \"Safari\" to return URL of front document"
        } else if appName.contains("Chrome") || appName.contains("Edge") || appName.contains("Brave") || appName.contains("Opera") || appName.contains("Vivaldi") {
            scriptSource = "tell application \"\(appName)\" to return URL of active tab of front window"
        } else {
            return nil
        }
        
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            let descriptor = script.executeAndReturnError(&error)
            if error == nil, let url = descriptor.stringValue {
                return url
            }
        }
        return nil
    }
}
