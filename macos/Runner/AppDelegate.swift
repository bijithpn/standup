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
import shared_preferences_foundation
import url_launcher_macos
import window_manager

func RegisterSecondaryPlugins(registry: FlutterPluginRegistry) {
    AppkitUiElementColorsPlugin.register(with: registry.registrar(forPlugin: "AppkitUiElementColorsPlugin"))
    AudioplayersDarwinPlugin.register(with: registry.registrar(forPlugin: "AudioplayersDarwinPlugin"))
    FlutterLocalNotificationsPlugin.register(with: registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin"))
    MacOSUiPlugin.register(with: registry.registrar(forPlugin: "MacOSUiPlugin"))
    MacOSWindowUtilsPlugin.register(with: registry.registrar(forPlugin: "MacOSWindowUtilsPlugin"))
    FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
    ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
    SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
    UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
    WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}

@main
class AppDelegate: FlutterAppDelegate, SPUUpdaterDelegate {
  var meetingBridge: MeetingDetectionBridge?
  var focusBridge: FocusModeBridge?
  var overlayBridge: OverlayWindowBridge?
  var windowBridge: WindowBridge?
  var sparkleBridge: SparkleBridge?
  
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
      windowBridge = WindowBridge(registrar: registrar)
      sparkleBridge = SparkleBridge(registrar: registrar, updater: updaterController.updater)
    }
    
    super.applicationDidFinishLaunching(notification)
    
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
    sparkleBridge?.updater(updater, didFindValidUpdate: item)
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    sparkleBridge?.updaterDidNotFindUpdate(updater)
  }

  func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
    sparkleBridge?.updater(updater, didAbortWithError: error)
  }
}

// MARK: - WindowBridge

class WindowBridge: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let bridge = WindowBridge(registrar: registrar)
        registrar.addMethodCallDelegate(bridge, channel: bridge.channel)
    }
    
    init(registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name: "com.breakmate/window",
            binaryMessenger: registrar.messenger
        )
        super.init()
        registrar.addMethodCallDelegate(self, channel: channel)
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleSetWindowLevel(args: [String: Any]?, result: FlutterResult) {
        guard let levelStr = args?["level"] as? String,
              let window = NSApp.mainWindow ?? NSApp.keyWindow else {
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
              let window = NSApp.mainWindow ?? NSApp.keyWindow else {
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
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            result(["x": 0.0, "y": 0.0])
            return
        }
        result(["x": window.frame.origin.x, "y": window.frame.origin.y])
    }
    
    private func handleSetWindowOpacity(args: [String: Any]?, result: FlutterResult) {
        guard let opacity = args?["opacity"] as? Double,
              let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            result(nil)
            return
        }
        window.alphaValue = CGFloat(opacity)
        result(nil)
    }
    
    private func handleSetIgnoresMouseEvents(args: [String: Any]?, result: FlutterResult) {
        guard let ignore = args?["ignore"] as? Bool,
              let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            result(nil)
            return
        }
        window.ignoresMouseEvents = ignore
        result(nil)
    }
    
    private func handleSetHasShadow(args: [String: Any]?, result: FlutterResult) {
        guard let hasShadow = args?["hasShadow"] as? Bool,
              let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            result(nil)
            return
        }
        window.hasShadow = hasShadow
        result(nil)
    }
    
    private func handleSetAcceptsMouseMovedEvents(args: [String: Any]?, result: FlutterResult) {
        guard let accept = args?["accept"] as? Bool,
              let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            result(nil)
            return
        }
        window.acceptsMouseMovedEvents = accept
        result(nil)
    }
    
    private func handleOrderFrontRegardless(result: FlutterResult) {
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            result(nil)
            return
        }
        window.orderFrontRegardless()
        result(nil)
    }
    
    private func handleHideWindow(result: FlutterResult) {
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            result(nil)
            return
        }
        window.orderOut(nil)
        result(nil)
    }
    
    private func handleShowWindow(result: FlutterResult) {
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            result(nil)
            return
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        result(nil)
    }
    
    private func handleSetWindowStyle(args: [String: Any]?, result: FlutterResult) {
        guard let style = args?["style"] as? String,
              let window = NSApp.mainWindow ?? NSApp.keyWindow else {
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
}

// MARK: - SparkleBridge

class SparkleBridge: NSObject {
    private let channel: FlutterMethodChannel
    private let updater: SPUUpdater
    
    init(registrar: FlutterPluginRegistrar, updater: SPUUpdater) {
        self.channel = FlutterMethodChannel(
            name: "com.breakmate/sparkle",
            binaryMessenger: registrar.messenger
        )
        self.updater = updater
        super.init()
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "checkForUpdates":
                self?.updater.checkForUpdatesInBackground()
                result(nil)
            case "startUpdate":
                // Standard Sparkle user-facing update check and installation flow
                self?.updater.checkForUpdates()
                result(nil)
            default:
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
