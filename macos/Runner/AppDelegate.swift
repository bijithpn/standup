import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var meetingBridge: MeetingDetectionBridge?
  var focusBridge: FocusModeBridge?
  var overlayBridge: OverlayWindowBridge?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if let window = mainFlutterWindow as? MainFlutterWindow {
      window.triggerReopen()
      if window.isMiniaturized { window.deminiaturize(nil) }
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
    }
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    OverlayWindowManager.shared.hideOverlay()
    CompanionWindowManager.shared.hideCompanion()
    super.applicationWillTerminate(notification)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let registrar = controller.registrar(forPlugin: "AppBridges")
      
      meetingBridge = MeetingDetectionBridge(registrar: registrar)
      focusBridge = FocusModeBridge(registrar: registrar)
      overlayBridge = OverlayWindowBridge(registrar: registrar)
    }
    
    super.applicationDidFinishLaunching(notification)
  }
}
