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
/// Secondary isolates reuse these plugin instances to handle display queries, audio playback, and visual effects.
func RegisterSecondaryPlugins(registry: FlutterPluginRegistry) {
    // Register only the critical plugins required for secondary isolates (overlays and companion)
    // to keep memory and CPU footprint low on lower-end macOS devices.
    //
    // NOTE: WindowManagerPlugin is intentionally excluded here. Secondary engines are headless
    // (no NSWindow/view), so WindowManagerPlugin.mainWindow force-unwraps a nil view and
    // crashes the process the moment any window_manager Dart call reaches the secondary isolate.
    ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
    AudioplayersDarwinPlugin.register(with: registry.registrar(forPlugin: "AudioplayersDarwinPlugin"))
    FlutterLocalNotificationsPlugin.register(with: registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin"))
    MacOSWindowUtilsPlugin.register(with: registry.registrar(forPlugin: "MacOSWindowUtilsPlugin"))
    
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
    let currentProcessId = currentApp.processIdentifier
    
    var terminatedAny = false
    
    for app in runningApps {
      if app.processIdentifier == currentProcessId { continue }
      
      let isSameBundle = currentBundleId != nil && app.bundleIdentifier == currentBundleId
      if isSameBundle {
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
  
  // The updater is started a couple of seconds after launch (see applicationDidFinishLaunching) so
  // Sparkle's setup does not sit on the main thread while the first window is being created.
  lazy var updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    // A finished/skipped break dismisses the overlay panels, which macOS can
    // report as a reopen. Don't open the app window because of that.
    let overlay = OverlayWindowManager.shared
    if overlay.isOverlayShowing || Date().timeIntervalSince(overlay.lastHideTime) < 2.0 {
      return true
    }
    if let window = mainFlutterWindow as? MainFlutterWindow {
      window.triggerReopen()
      window.showOnCurrentSpace()
    }
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    OverlayWindowManager.shared.destroyAllInstances()
    CompanionWindowManager.shared.hideCompanion()
    PiPFlutterWindowManager.shared.hidePipWindow()
    // The WebView build of this window is no longer routed to, but tear it down
    // too in case an older session left one on screen.
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
      NativeSmartDetector.shared.register(with: registrar.messenger)

      let enhancementChannel = FlutterMethodChannel(name: "com.breakmate/native_enhancements", binaryMessenger: registrar.messenger)
      enhancementChannel.setMethodCallHandler { call, result in
          switch call.method {
          case "showCursorCountdown":
              let seconds = (call.arguments as? [String: Any])?["seconds"] as? Int ?? 15
              NativeCursorCountdownWindow.shared.startCountdown(seconds: seconds)
              result(nil)
          case "hideCursorCountdown":
              NativeCursorCountdownWindow.shared.dismissCountdown()
              result(nil)
          case "triggerFlashReminder":
              guard let args = call.arguments as? [String: Any],
                    let text = args["text"] as? String else {
                  result(FlutterError(code: "INVALID_ARGS", message: "text required", details: nil))
                  return
              }
              let duration = args["durationMs"] as? Int ?? 250
              let opacity = CGFloat(args["opacity"] as? Double ?? 0.35)
              let colorHex = args["colorHex"] as? String ?? "#000000"
              NativeFlashReminderWindow.shared.triggerFlash(text: text, durationMs: duration, opacity: opacity, colorHex: colorHex)
              result(nil)
          case "preventDisplaySleep":
              let reason = (call.arguments as? [String: Any])?["reason"] as? String ?? "BreakMate Break Active"
              NativePowerAssertionManager.shared.preventDisplaySleep(reason: reason)
              result(nil)
          case "releaseDisplaySleep":
              NativePowerAssertionManager.shared.releaseDisplaySleep()
              result(nil)
          default:
              result(FlutterMethodNotImplemented)
          }
      }

      focusBridge = FocusModeBridge(registrar: registrar)
      overlayBridge = OverlayWindowBridge(registrar: registrar)
      windowBridge = WindowBridge(registrar: registrar)
      sparkleBridge = SparkleBridge(registrar: registrar, updater: updaterController.updater)
      appTrackingBridge = AppTrackingBridge(registrar: registrar)
      NSLog("Sparkle: Initialized SparkleBridge with updater: \(updaterController.updater)")
    }
    
    super.applicationDidFinishLaunching(notification)
    NSLog("Sparkle: applicationDidFinishLaunching completed")

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      self?.updaterController.startUpdater()
    }
    
    DispatchQueue.main.async { [weak self] in
      if let window = self?.mainFlutterWindow {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
      }
    }
    
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

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        guard let error = error else { return }
        NSLog("Sparkle: Update check cycle failed: \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }
}

// MARK: - WindowBridge

class WindowBridge: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private weak var registrar: FlutterPluginRegistrar?
    
    /// Whether this bridge may act on the app's main window when its own
    /// engine has no window attached.
    ///
    /// True for the main engine, where "the window" and "the app's window" are
    /// the same thing. False for every secondary engine — see `window`.
    private let allowsAppWindowFallback: Bool

    /// Secondary engines (companion, PiP, overlays) register through here.
    static func register(with registrar: FlutterPluginRegistrar) {
        let bridge = WindowBridge(registrar: registrar, allowsAppWindowFallback: false)
        registrar.addMethodCallDelegate(bridge, channel: bridge.channel)
    }

    init(registrar: FlutterPluginRegistrar, allowsAppWindowFallback: Bool = true) {
        self.registrar = registrar
        self.allowsAppWindowFallback = allowsAppWindowFallback
        channel = FlutterMethodChannel(
            name: "com.breakmate/window",
            binaryMessenger: registrar.messenger
        )
        super.init()
        registrar.addMethodCallDelegate(self, channel: channel)
    }

    /// The window this bridge is allowed to touch.
    ///
    /// A secondary engine owns exactly one window, and if that window is not
    /// attached yet there is simply nothing to act on. Falling back to the
    /// app's main window here would be actively harmful now that the companion
    /// moves its own window around the screen: a failed lookup in the PiP
    /// engine would send the user's main BreakMate window wandering off
    /// instead of the pet.
    private var window: NSWindow? {
        if let own = registrar?.view?.window { return own }
        guard allowsAppWindowFallback else {
            // Logged once rather than per call: the companion asks to be moved
            // twenty-five times a second while it walks, and this is the one
            // thing that would make that silently do nothing.
            if !hasWarnedAboutMissingWindow {
                hasWarnedAboutMissingWindow = true
                NSLog("WindowBridge: secondary engine has no window attached; window calls are being ignored")
            }
            return nil
        }
        return NSApp.mainWindow ?? NSApp.keyWindow
    }

    private var hasWarnedAboutMissingWindow = false
    
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
        // `animate: true` runs a nested run loop until AppKit's animation
        // finishes. That is right for a one-off move and ruinous for the
        // companion's wandering, which sets a new position twenty-five times a
        // second: every call would block the main thread, and each animation
        // would be fighting the one before it. Callers driving their own
        // motion pass false and get an immediate move.
        let animate = args?["animate"] as? Bool ?? true
        window.setFrame(frame, display: true, animate: animate)
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
        (window as? MainFlutterWindow)?.showOnCurrentSpace()
        if !(window is MainFlutterWindow) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
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
                // This app action needs a fresh check with a result in our own UI.
                // An informational probe bypasses the background scheduler and
                // does not open Sparkle's separate update window.
                guard let self = self else {
                    result(FlutterError(code: "UPDATER_UNAVAILABLE", message: "The updater is unavailable.", details: nil))
                    return
                }
                guard self.updater.canCheckForUpdates else {
                    result(FlutterError(code: "UPDATE_CHECK_UNAVAILABLE", message: "An update check cannot be started right now.", details: nil))
                    return
                }
                NSLog("SparkleBridge: Triggering checkForUpdateInformation")
                self.updater.checkForUpdateInformation()
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
