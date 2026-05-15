import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let window = mainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController else {
      super.applicationDidFinishLaunching(notification)
      return
    }
    
    let channel = FlutterMethodChannel(name: "com.breakmate.macos/bridge", binaryMessenger: controller.engine.binaryMessenger)

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "setWindowLevel":
        if let args = call.arguments as? [String: Any],
           let levelStr = args["level"] as? String {
          self.setWindowLevel(levelStr)
          result(nil)
        }
      case "setPresentationOptions":
        if let args = call.arguments as? [String: Any],
           let hideDock = args["hideDock"] as? Bool,
           let hideMenu = args["hideMenu"] as? Bool {
          self.setPresentationOptions(hideDock: hideDock, hideMenu: hideMenu)
          result(nil)
        }
      case "getIdleTime":
        let idleTime = self.getIdleTime()
        result(idleTime)
      case "getAppearance":
        let isDark = NSAppearance.current?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        result(isDark ? "dark" : "light")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    super.applicationDidFinishLaunching(notification)
  }

  private func setWindowLevel(_ level: String) {
    guard let window = mainFlutterWindow else { return }
    switch level {
    case "screenSaver":
      window.level = .screenSaver
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    case "floating":
      window.level = .floating
      window.collectionBehavior = [.canJoinAllSpaces]
    default:
      window.level = .normal
      window.collectionBehavior = [.moveToActiveSpace, .managed]
    }
  }

  private func setPresentationOptions(hideDock: Bool, hideMenu: Bool) {
    var options: NSApplication.PresentationOptions = []
    if hideDock { options.insert(.hideDock); options.insert(.autoHideDock) }
    if hideMenu { options.insert(.hideMenuBar); options.insert(.autoHideMenuBar) }
    
    if options.isEmpty {
      NSApp.presentationOptions = []
    } else {
      NSApp.presentationOptions = options
    }
  }

  private func getIdleTime() -> Double {
    // kCGAnyInputEventType is ((CGEventType)(~0))
    let anyEvent = CGEventType(rawValue: ~0)!
    let idleTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.combinedSessionState, eventType: anyEvent)
    return idleTime
  }
}
