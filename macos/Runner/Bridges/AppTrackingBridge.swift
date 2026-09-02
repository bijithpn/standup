import Cocoa
import FlutterMacOS

class AppTrackingBridge: NSObject {
    private let channel: FlutterMethodChannel
    // getActiveApp is polled every ~10s from two independent Dart-side
    // timers (app usage tracking + smart meeting detection). The
    // AppleScript/Accessibility lookups it does to read a browser's active
    // tab URL can take anywhere from a few ms to well over a second (a busy
    // browser, first-time AppleScript compilation, a hung target app), and
    // running that synchronously on the platform/main thread was a real
    // source of UI jank and input lag app-wide. Do that work here instead.
    private let workQueue = DispatchQueue(label: "com.breakmate.app-tracking", qos: .utility)

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
            case "getAppIcon":
                self?.handleGetAppIcon(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func handleGetActiveApp(result: @escaping FlutterResult) {
        // NSWorkspace reads are cheap and expected on the main thread — do
        // those here, then hop off-thread for the slow lookups below.
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            result(nil)
            return
        }

        let appName = frontmostApp.localizedName ?? "Unknown"
        let bundleId = frontmostApp.bundleIdentifier ?? "Unknown"
        let exeName = frontmostApp.executableURL?.lastPathComponent ?? "Unknown"
        let pid = frontmostApp.processIdentifier

        workQueue.async { [weak self] in
            guard let self = self else { return }

            var displayName = appName
            // If accessibility permissions are available, read the active window title.
            if let windowTitle = self.getActiveWindowTitle(pid: pid) {
                displayName = windowTitle
            }

            var appInfo: [String: Any] = [
                "name": displayName,
                "bundleId": bundleId,
                "executableName": exeName
            ]

            if let url = self.getBrowserUrl(appName: appName) {
                appInfo["url"] = url
            }

            DispatchQueue.main.async {
                result(appInfo)
            }
        }
    }

    private func handleGetAppIcon(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bundleId = args["bundleId"] as? String,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            result(nil)
            return
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)

        guard let tiff = icon.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            result(nil)
            return
        }

        result(FlutterStandardTypedData(bytes: png))
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
