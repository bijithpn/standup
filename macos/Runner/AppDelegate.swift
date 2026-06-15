import Cocoa
import FlutterMacOS
import Sparkle
import appkit_ui_element_colors
import audioplayers_darwin
import flutter_local_notifications
import macos_ui
import macos_window_utils
import package_info_plus
import screen_retriever_macos
import url_launcher_macos
import window_manager

/// Registers all required Flutter plugins for secondary engines (overlays, companion).
/// This now uses the standard GeneratedPluginRegistrant for 100% feature parity with the main engine.
func RegisterSecondaryPlugins(registry: FlutterPluginRegistry) {
    RegisterGeneratedPlugins(registry: registry)
    WindowBridge.register(with: registry.registrar(forPlugin: "WindowBridge"))
    BehaviorEngineBridge.register(with: registry.registrar(forPlugin: "BehaviorEngineBridge"))
}

@main
class AppDelegate: FlutterAppDelegate, SPUUpdaterDelegate {
  var meetingBridge: MeetingDetectionBridge?
  var focusBridge: FocusModeBridge?
  var overlayBridge: OverlayWindowBridge?
  var windowBridge: WindowBridge?
  var sparkleBridge: SparkleBridge?
  var appTrackingBridge: AppTrackingBridge?
  
  override func applicationWillFinishLaunching(_ notification: Notification) {
    // Aggressively terminate any stale running instances of BreakMate (e.g. background menu bar process from a previous debug run)
    // to unlock the ObjectBox database, clean up the status bar, and enforce single-instance execution.
    let currentApp = NSRunningApplication.current
    let runningApps = NSWorkspace.shared.runningApplications
    let currentBundleId = currentApp.bundleIdentifier
    let currentLocalizedName = currentApp.localizedName
    let currentBundleName = currentApp.bundleURL?.lastPathComponent
    let currentProcessId = currentApp.processIdentifier
    
    var terminatedAny = false
    
    for app in runningApps {
      if app.processIdentifier == currentProcessId { continue }
      
      let isSameBundle = currentBundleId != nil && app.bundleIdentifier == currentBundleId
      let isSameName = currentLocalizedName != nil && app.localizedName == currentLocalizedName
      let isSameBundleName = currentBundleName != nil && app.bundleURL?.lastPathComponent == currentBundleName
      
      // Specifically target "com.bijith.breakmate" or "BreakMate" as additional safety fallbacks
      let isTargetBundle = app.bundleIdentifier == "com.bijith.breakmate"
      let isTargetName = app.localizedName?.lowercased().contains("breakmate") == true || app.localizedName?.lowercased().contains("break-mate") == true
      let isTargetBundleName = app.bundleURL?.lastPathComponent.lowercased().contains("breakmate") == true || app.bundleURL?.lastPathComponent.lowercased().contains("break-mate") == true
      
      if isSameBundle || isSameName || isSameBundleName || isTargetBundle || isTargetName || isTargetBundleName {
        NSLog("Terminating stale running instance of BreakMate (PID: \(app.processIdentifier), Name: \(app.localizedName ?? "unknown")) to release database lock")
        app.forceTerminate()
        terminatedAny = true
      }
    }
    
    // If we terminated another instance, wait briefly (500ms) to allow the OS kernel to fully clean up
    // the process and release POSIX file locks on the ObjectBox database files.
    if terminatedAny {
      Thread.sleep(forTimeInterval: 0.5)
    }
    
    super.applicationWillFinishLaunching(notification)
  }
  
  lazy var updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)

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
    PiPWindowManager.shared.hidePipWindow()
    super.applicationWillTerminate(notification)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
    let registrar = controller.registrar(forPlugin: "AppBridges")

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    NSLog("Sparkle: App Version: \(version) (\(build))")

    let feedUrl = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "NOT FOUND"

    let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? "NOT FOUND"
    NSLog("Sparkle: Configured with Feed URL: \(feedUrl)")
    NSLog("Sparkle: Configured with Public Key: \(publicKey)")

    meetingBridge = MeetingDetectionBridge(registrar: registrar)

      focusBridge = FocusModeBridge(registrar: registrar)
      overlayBridge = OverlayWindowBridge(registrar: registrar)
      windowBridge = WindowBridge(registrar: registrar)
      sparkleBridge = SparkleBridge(registrar: registrar, updater: updaterController.updater)
      appTrackingBridge = AppTrackingBridge(registrar: registrar)
      NSLog("Sparkle: Initialized SparkleBridge with updater: \(updaterController.updater)")
    }
    
    super.applicationDidFinishLaunching(notification)
    NSLog("Sparkle: applicationDidFinishLaunching completed")
    
    if let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu {
      let checkForUpdatesItem = NSMenuItem(
        title: "Check for Updates...",
        action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
        keyEquivalent: ""
      )
      checkForUpdatesItem.target = updaterController
      appMenu.insertItem(checkForUpdatesItem, at: 2)
    }
  }

    // MARK: - SPUUpdaterDelegate
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        NSLog("Sparkle: Found valid update: \(item.displayVersionString) (\(item.versionString))")
        sparkleBridge?.updater(updater, didFindValidUpdate: item)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        NSLog("Sparkle: Did not find update")
        sparkleBridge?.updaterDidNotFindUpdate(updater)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        NSLog("Sparkle: Update aborted with error: \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }
    
    func updater(_ updater: SPUUpdater, didFailToRegisterUpdateWithItem item: SUAppcastItem, error: Error) {
        NSLog("Sparkle: Failed to register update \(item.displayVersionString): \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }
    
    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        NSLog("Sparkle: Failed to download update \(item.displayVersionString): \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }
    
    func updater(_ updater: SPUUpdater, didFailToInstallUpdate item: SUAppcastItem, error: Error) {
        NSLog("Sparkle: Failed to install update \(item.displayVersionString): \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }

    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        NSLog("Sparkle: Next update check scheduled in \(delay) seconds")
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        NSLog("Sparkle: Finished loading appcast with \(appcast.items.count) items")
    }
}

// MARK: - WindowBridge

class WindowBridge: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private weak var registrar: FlutterPluginRegistrar?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let bridge = WindowBridge(registrar: registrar)
        registrar.addMethodCallDelegate(bridge, channel: bridge.channel)
    }
    
    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        channel = FlutterMethodChannel(
            name: "com.breakmate/window",
            binaryMessenger: registrar.messenger
        )
        super.init()
        registrar.addMethodCallDelegate(self, channel: channel)
    }
    
    private var window: NSWindow? {
        return registrar?.view?.window ?? NSApp.mainWindow ?? NSApp.keyWindow
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        
        switch call.method {
        case "setWindowLevel":
            handleSetWindowLevel(args: args, result: result)
        case "setWindowPosition":
            handleSetWindowPosition(args: args, result: result)
        case "getWindowPosition":
            handleGetWindowPosition(result: result)
        case "setWindowOpacity":
            handleSetWindowOpacity(args: args, result: result)
        case "setIgnoresMouseEvents":
            handleSetIgnoresMouseEvents(args: args, result: result)
        case "setHasShadow":
            handleSetHasShadow(args: args, result: result)
        case "setAcceptsMouseMovedEvents":
            handleSetAcceptsMouseMovedEvents(args: args, result: result)
        case "orderFrontRegardless":
            handleOrderFrontRegardless(result: result)
        case "hideWindow":
            handleHideWindow(result: result)
        case "showWindow":
            handleShowWindow(result: result)
        case "setWindowStyle":
            handleSetWindowStyle(args: args, result: result)
        case "setWindowSize":
            handleSetWindowSize(args: args, result: result)
        case "startDrag":
            handleStartDrag(result: result)
        case "setNonActivating":
            handleSetNonActivating(args: args, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleSetWindowLevel(args: [String: Any]?, result: FlutterResult) {
        guard let levelStr = args?["level"] as? String,
              let window = self.window else {
            result(nil)
            return
        }
        
        switch levelStr {
        case "floating": window.level = .floating
        case "normal": window.level = .normal
        case "statusBar": window.level = .statusBar
        case "modalPanel": window.level = .modalPanel
        case "popUpMenu": window.level = .popUpMenu
        case "screenSaver": window.level = .screenSaver
        default: break
        }
        result(nil)
    }
    
    private func handleSetWindowPosition(args: [String: Any]?, result: FlutterResult) {
        guard let x = args?["x"] as? Double,
              let y = args?["y"] as? Double,
              let window = self.window else {
            result(nil)
            return
        }
        
        var frame = window.frame
        frame.origin.x = x
        frame.origin.y = y
        window.setFrame(frame, display: true, animate: true)
        result(nil)
    }
    
    private func handleGetWindowPosition(result: FlutterResult) {
        guard let window = self.window else {
            result(["x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0])
            return
        }
        result([
            "x": window.frame.origin.x,
            "y": window.frame.origin.y,
            "width": Double(window.frame.size.width),
            "height": Double(window.frame.size.height)
        ])
    }
    
    private func handleSetWindowOpacity(args: [String: Any]?, result: FlutterResult) {
        guard let opacity = args?["opacity"] as? Double,
              let window = self.window else {
            result(nil)
            return
        }
        window.alphaValue = CGFloat(opacity)
        result(nil)
    }
    
    private func handleSetIgnoresMouseEvents(args: [String: Any]?, result: FlutterResult) {
        guard let ignore = args?["ignore"] as? Bool,
              let window = self.window else {
            result(nil)
            return
        }
        window.ignoresMouseEvents = ignore
        result(nil)
    }
    
    private func handleSetHasShadow(args: [String: Any]?, result: FlutterResult) {
        guard let hasShadow = args?["hasShadow"] as? Bool,
              let window = self.window else {
            result(nil)
            return
        }
        window.hasShadow = hasShadow
        result(nil)
    }
    
    private func handleSetAcceptsMouseMovedEvents(args: [String: Any]?, result: FlutterResult) {
        guard let accept = args?["accept"] as? Bool,
              let window = self.window else {
            result(nil)
            return
        }
        window.acceptsMouseMovedEvents = accept
        result(nil)
    }
    
    private func handleOrderFrontRegardless(result: FlutterResult) {
        guard let window = self.window else {
            result(nil)
            return
        }
        window.orderFrontRegardless()
        result(nil)
    }
    
    private func handleHideWindow(result: FlutterResult) {
        guard let window = self.window else {
            result(nil)
            return
        }
        window.orderOut(nil)
        result(nil)
    }
    
    private func handleShowWindow(result: FlutterResult) {
        guard let window = self.window else {
            result(nil)
            return
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        result(nil)
    }
    
    private func handleSetWindowStyle(args: [String: Any]?, result: FlutterResult) {
        guard let style = args?["style"] as? String,
              let window = self.window else {
            result(nil)
            return
        }
        
        switch style {
        case "borderless": window.styleMask = [.borderless, .nonactivatingPanel]
        case "titled": window.styleMask = [.titled, .closable, .miniaturizable]
        case "utility": window.styleMask = [.titled, .closable, .utilityWindow]
        case "hud": window.styleMask = [.titled, .closable, .hudWindow]
        default: break
        }
        result(nil)
    }

    private func handleSetWindowSize(args: [String: Any]?, result: FlutterResult) {
        guard let width = args?["width"] as? Double,
              let height = args?["height"] as? Double,
              let window = self.window else {
            result(nil)
            return
        }
        var frame = window.frame
        let deltaY = frame.size.height - CGFloat(height)
        frame.origin.y += deltaY
        frame.size.width = CGFloat(width)
        frame.size.height = CGFloat(height)
        window.setFrame(frame, display: true, animate: true)
        result(nil)
    }

    private func handleStartDrag(result: FlutterResult) {
        guard let window = self.window else {
            result(nil)
            return
        }
        if let event = NSApp.currentEvent {
            window.performDrag(with: event)
        }
        result(nil)
    }

    private func handleSetNonActivating(args: [String: Any]?, result: FlutterResult) {
        guard let nonActivating = args?["nonActivating"] as? Bool,
              let window = self.window else {
            result(nil)
            return
        }
        if nonActivating {
            window.styleMask.insert(.nonactivatingPanel)
        } else {
            window.styleMask.remove(.nonactivatingPanel)
        }
        result(nil)
    }
}

// MARK: - SparkleBridge

class SparkleBridge: NSObject {
    private let channel: FlutterMethodChannel
    private let updater: SPUUpdater
    
    init(registrar: FlutterPluginRegistrar, updater: SPUUpdater) {
        NSLog("SparkleBridge: Initializing channel com.breakmate/sparkle")
        self.channel = FlutterMethodChannel(
            name: "com.breakmate/sparkle",
            binaryMessenger: registrar.messenger
        )
        self.updater = updater
        super.init()
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            NSLog("SparkleBridge: Received method call: \(call.method)")
            switch call.method {
            case "checkForUpdates":
                NSLog("SparkleBridge: Triggering checkForUpdatesInBackground")
                self?.updater.checkForUpdatesInBackground()
                result(nil)
            case "startUpdate":
                NSLog("SparkleBridge: Triggering checkForUpdates (User-facing)")
                // Standard Sparkle user-facing update check and installation flow
                self?.updater.checkForUpdates()
                result(nil)
            default:
                NSLog("SparkleBridge: Method not implemented: \(call.method)")
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let notes = item.itemDescription ?? "No release notes available."
        let version = item.displayVersionString
        let args: [String: Any] = [
            "hasUpdate": true,
            "version": version,
            "notes": notes
        ]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onUpdateResult", arguments: args)
        }
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        let args: [String: Any] = [
            "hasUpdate": false,
            "version": "",
            "notes": ""
        ]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onUpdateResult", arguments: args)
        }
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let args: [String: Any] = [
            "hasUpdate": false,
            "error": error.localizedDescription
        ]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onUpdateError", arguments: args)
        }
    }
}
