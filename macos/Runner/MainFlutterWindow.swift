import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var bridgeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureBridge(binaryMessenger: flutterViewController.engine.binaryMessenger)

    // Configure window to stay in background - NOT on all desktops
    self.isOpaque = false
    self.hasShadow = true
    self.level = .normal  // Normal window level (not floating)
    self.collectionBehavior = [.managed, .moveToActiveSpace]  // Only show in current space
    self.isMovableByWindowBackground = false
    
    // Enable vibrancy (macOS acrylic-like effect)
    self.backgroundColor = NSColor.clear
    self.contentViewController?.view.wantsLayer = true
    
    // Set window to be transparent
    self.alphaValue = 1.0

    super.awakeFromNib()
  }

  private func configureBridge(binaryMessenger: FlutterBinaryMessenger) {
    bridgeChannel = FlutterMethodChannel(
      name: "com.breakmate.macos/bridge",
      binaryMessenger: binaryMessenger
    )

    bridgeChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "WINDOW_NOT_FOUND", message: "MainFlutterWindow not found", details: nil))
        return
      }

      switch call.method {
      case "showOverlay":
        if self.isMiniaturized { self.deminiaturize(nil) }
        self.configureAsOverlay()
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        result(nil)

      case "hideOverlay":
        self.resetToNormal()
        result(nil)

      case "setWindowLevel":
        if let args = call.arguments as? [String: Any],
           let level = args["level"] as? String {
          self.setWindowLevel(level)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing level", details: nil))
        }

      case "setPresentationOptions":
        if let args = call.arguments as? [String: Any],
           let hideDock = args["hideDock"] as? Bool,
           let hideMenu = args["hideMenu"] as? Bool {
          self.setPresentationOptions(hideDock: hideDock, hideMenu: hideMenu)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
        }

      case "getIdleTime":
        result(self.getIdleTime())

      case "getAppearance":
        let isDark = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        result(isDark ? "dark" : "light")

      case "focusApp":
        if self.isMiniaturized { self.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        result(nil)

      case "getFrontmostApp":
        result(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)

      case "isFocusModeActive":
        result(self.checkFocusModeActive())

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setWindowLevel(_ level: String) {
    switch level {
    case "screenSaver":
      self.level = .screenSaver
      self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    case "floating":
      self.level = .floating
      self.collectionBehavior = [.canJoinAllSpaces]
    default:
      self.level = .normal
      self.collectionBehavior = [.moveToActiveSpace, .managed]
    }
  }

  private func setPresentationOptions(hideDock: Bool, hideMenu: Bool) {
    var options: NSApplication.PresentationOptions = []
    if hideDock {
      options.insert(.hideDock)
      options.insert(.autoHideDock)
    }
    if hideMenu {
      options.insert(.hideMenuBar)
      options.insert(.autoHideMenuBar)
    }
    NSApp.presentationOptions = options
  }

  private func getIdleTime() -> Double {
    let anyEvent = CGEventType(rawValue: ~0)!
    return CGEventSource.secondsSinceLastEventType(
      CGEventSourceStateID.combinedSessionState,
      eventType: anyEvent
    )
  }

  private func checkFocusModeActive() -> Bool {
    let path = NSString(string: "~/Library/Preferences/com.apple.notificationcenterui.plist").expandingTildeInPath
    if let prefs = NSDictionary(contentsOfFile: path),
       let dndEnabled = prefs["doNotDisturb"] as? Bool {
      return dndEnabled
    }
    return false
  }

  /// Configure this window as a full-screen overlay
  func configureAsOverlay() {
    self.isOpaque = false
    self.hasShadow = false
    self.level = .screenSaver  // Higher level for overlay only
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    self.styleMask = [.borderless]
    self.isMovableByWindowBackground = false
    self.ignoresMouseEvents = false
    self.backgroundColor = NSColor.black.withAlphaComponent(0.95)
    
    // Ensure the content view covers the entire window
    if let screen = self.screen ?? NSScreen.main {
        self.setFrame(screen.frame, display: true)
    }
  }

  /// Configure this window to ignore mouse events (click-through)
  func setIgnoreMouseEvents(_ ignore: Bool) {
    self.ignoresMouseEvents = ignore
  }
  
  /// Reset window to normal state (background, not on top)
  func resetToNormal() {
    self.level = .normal  // Normal level - not on top
    self.collectionBehavior = [.managed, .moveToActiveSpace]  // Only current space
    self.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    self.isMovableByWindowBackground = true
    self.ignoresMouseEvents = false
    self.hasShadow = true
    self.backgroundColor = NSColor.windowBackgroundColor
    
    // Resize back to a reasonable size if it was full screen
    // or just let Flutter handle resizing via window_manager
  }
}
