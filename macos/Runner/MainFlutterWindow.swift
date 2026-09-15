import Cocoa
import FlutterMacOS

class OverlayPanel: NSPanel {
    var isReminder: Bool = false
    
    override var canBecomeKey: Bool { return !isReminder }
    override var canBecomeMain: Bool { return !isReminder }
}

class OverlayWindowManager: NSObject {
    static let shared = OverlayWindowManager()
    
    private var overlayInstances: [NSScreen: OverlayInstance] = [:]
    var lastShowArgs: [String: Any]? // Persisted arguments for active overlay
    private var wasMainWindowVisible: Bool = false
    private var lastScreensHash: Int = 0
    private var showGeneration: Int = 0
    
    struct OverlayInstance {
        let window: OverlayPanel
        let engine: FlutterEngine
        let controller: FlutterViewController
    }
    
    func showOverlay(args: [String: Any]? = nil) {
        self.lastShowArgs = args
        
        if !overlayInstances.isEmpty {
            if let args = args {
                updateData(args)
            }
            return
        }
        
        let type = args?["type"] as? String ?? "breakScreen"
        let isReminder = type == "quickReminder" || type == "preBreakWarning"
        let isPreview = args?["isPreview"] as? Bool ?? false
        
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let mainWindow = appDelegate.mainFlutterWindow else {
            return
        }
        
        // Only hide main window for real full break screens, not for reminders or previews
        if !isReminder && !isPreview {
            wasMainWindowVisible = mainWindow.isVisible
            mainWindow.orderOut(nil)
        }
        
        let showOnAllDisplays = args?["showOnAllDisplays"] as? Bool ?? true
        let screens = showOnAllDisplays ? NSScreen.screens : (NSScreen.main.map { [$0] } ?? NSScreen.screens)
        
        for screen in screens {
            let instance = createOverlayInstance(for: screen, args: args)
            instance.window.isReminder = isReminder
            overlayInstances[screen] = instance
            
            instance.window.alphaValue = 0.0
            
            // For reminders, use orderFront to avoid stealing focus from other apps
            // For full screens, make the (non-activating) panel key so it actually
            // receives keyboard events (Escape / any-key dismiss) — a panel that is
            // merely ordered front never becomes key and silently swallows no input,
            // it just never gets any. `.nonactivatingPanel` means this does not
            // steal focus from the owning app or other apps, so it's still safe to
            // do over fullscreen apps.
            if isReminder {
                instance.window.orderFront(nil)
            } else {
                instance.window.orderFrontRegardless()
                instance.window.makeKey()
            }
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                instance.window.animator().alphaValue = 1.0
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Reminders can't become key windows (by design, so they don't steal
        // focus), so they can only be dismissed by the Dart side's own timer.
        // If that Flutter engine ever hangs or drops a message, the overlay
        // would otherwise sit there forever with no way for the user to
        // close it. This is a hard backstop, independent of Dart, so a
        // reminder always goes away on its own.
        if isReminder {
            showGeneration += 1
            let generation = showGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                guard let self = self, self.showGeneration == generation else { return }
                self.hideOverlay()
            }
        }
    }

    func hideOverlay(restoreMainWindow: Bool = true) {
        showGeneration += 1
        if overlayInstances.isEmpty { return }

        let instances = Array(overlayInstances.values)
        overlayInstances.removeAll()
        
        let shouldRestore = restoreMainWindow && wasMainWindowVisible
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            for instance in instances {
                instance.window.animator().alphaValue = 0.0
            }
        }, completionHandler: {
            // Restore main window visibility only if requested and was visible before
            if shouldRestore,
               let appDelegate = NSApp.delegate as? AppDelegate,
               let mainWindow = appDelegate.mainFlutterWindow {
                mainWindow.makeKeyAndOrderFront(nil)
            }
            
            for instance in instances {
                instance.window.orderOut(nil)
                instance.window.contentViewController = nil
                instance.window.contentView = nil
                
                let channel = FlutterMethodChannel(name: "com.breakmate.desktop/bridge", binaryMessenger: instance.engine.binaryMessenger)
                channel.setMethodCallHandler(nil)
                
                IpcBridgeManager.shared.unregister(engine: instance.engine)
                instance.engine.shutDownEngine()
            }
        })
        
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    func setClickThrough(_ enabled: Bool) {
        for instance in overlayInstances.values {
            instance.window.ignoresMouseEvents = enabled
        }
    }
    
    func updateData(_ data: [String: Any]) {
        for instance in overlayInstances.values {
            let channel = FlutterMethodChannel(name: "com.breakmate.desktop/bridge", binaryMessenger: instance.engine.binaryMessenger)
            channel.invokeMethod("updateOverlayData", arguments: data)
        }
    }
    
    func updateVisualEffect(materialName: String) {
        for instance in overlayInstances.values {
            guard let visualEffectView = instance.window.contentView as? NSVisualEffectView else { continue }
            
            switch materialName {
            case "hud": visualEffectView.material = .hudWindow
            case "dark": visualEffectView.material = .hudWindow
            case "light": visualEffectView.material = .popover
            case "ultraDark": visualEffectView.material = .fullScreenUI
            case "fullScreenUI": visualEffectView.material = .fullScreenUI
            default: visualEffectView.material = .hudWindow
            }
        }
    }
    
    @objc private func screenParametersChanged() {
        let screens = NSScreen.screens
        let screensHash = screens.map { "\($0.frame)-\($0.visibleFrame)" }.joined().hashValue
        if screensHash == lastScreensHash {
            return
        }
        lastScreensHash = screensHash
        
        let savedArgs = self.lastShowArgs
        hideOverlay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showOverlay(args: savedArgs)
        }
    }
    
    private func createOverlayInstance(for screen: NSScreen, args: [String: Any]?) -> OverlayInstance {
        let window = OverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        let isTransparent = args?["isTransparent"] as? Bool ?? false
        
        window.backgroundColor = isTransparent ? NSColor.clear : NSColor.black // Solid black background to prevent flickering
        window.isOpaque = !isTransparent
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = args?["ignoreMouseEvents"] as? Bool ?? false
        
        // Spawn a fresh engine for each monitor. 
        // Note: FlutterEngineGroup is not supported in the current macOS SDK version.
        let engine = FlutterEngine(name: "OverlayEngine-\(UUID().uuidString)", project: nil, allowHeadlessExecution: true)
        engine.run(withEntrypoint: "overlayMain")
        RegisterSecondaryPlugins(registry: engine)
        
        IpcBridgeManager.shared.register(engine: engine)
        
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        controller.backgroundColor = isTransparent ? NSColor.clear : NSColor.black
        
        window.contentViewController = controller
        window.setFrame(screen.frame, display: true)
        
        // Setup MethodChannel for this overlay
        let channel = FlutterMethodChannel(name: "com.breakmate.desktop/bridge", binaryMessenger: engine.binaryMessenger)
        
        // Pass initial data if available
        var initialArgs = args ?? [:]
        
        // Add display-specific metadata so the Flutter engine knows which screen it is rendering on
        var displayId = "Display_unknown"
        if #available(macOS 10.15, *) {
            displayId = screen.localizedName
        }
        initialArgs["displayId"] = displayId
        initialArgs["boundsWidth"] = screen.frame.width
        initialArgs["boundsHeight"] = screen.frame.height
        
        // Initial broadcast
        channel.invokeMethod("updateOverlayData", arguments: initialArgs)
        
        // Redundant broadcast with delay to catch the engine as it warms up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            channel.invokeMethod("updateOverlayData", arguments: initialArgs)
        }
        
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "getOverlayData":
                result(OverlayWindowManager.shared.lastShowArgs)
            case "checkIsMainEngine":
                result(false)
            case "hideOverlay":
                let restore = (call.arguments as? [String: Any])?["restoreMainWindow"] as? Bool ?? true
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let mainWindow = appDelegate.mainFlutterWindow as? MainFlutterWindow {
                    mainWindow.bridgeChannel?.invokeMethod("hideOverlay", arguments: ["restoreMainWindow": restore])
                }
                OverlayWindowManager.shared.hideOverlay(restoreMainWindow: restore)
                result(nil)
            case "skipBreak":
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let mainWindow = appDelegate.mainFlutterWindow as? MainFlutterWindow {
                    mainWindow.bridgeChannel?.invokeMethod("skipBreak", arguments: nil)
                }
                OverlayWindowManager.shared.hideOverlay()
                result(nil)
            case "completeBreak":
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let mainWindow = appDelegate.mainFlutterWindow as? MainFlutterWindow {
                    mainWindow.bridgeChannel?.invokeMethod("completeBreak", arguments: nil)
                }
                OverlayWindowManager.shared.hideOverlay()
                result(nil)
            case "setIgnoreMouseEvents":
                if let args = call.arguments as? [String: Any], let ignore = args["ignore"] as? Bool {
                    OverlayWindowManager.shared.setClickThrough(ignore)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing ignore parameter", details: nil))
                }
            case "enumerateDisplays", "getCursorPosition", "getVisibleWindows",
                 "showConstraintWindow", "hideConstraintWindow", "getIdleTime", "focusApp":
                BehaviorEngineBridge.shared.handle(call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        return OverlayInstance(window: window, engine: engine, controller: controller)
    }
}

class MainFlutterWindow: NSWindow {
  fileprivate var bridgeChannel: FlutterMethodChannel?

  // Dedicated bridge for all EventKit / calendar operations.
  // Declared as a lazy var so it is created after the window is fully set up.
  private lazy var calendarBridge = CalendarBridge()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = .clear
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor
    
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureBridge(binaryMessenger: flutterViewController.engine.binaryMessenger)
    BehaviorEngineBridge.shared.setup(binaryMessenger: flutterViewController.engine.binaryMessenger)
    
    IpcBridgeManager.shared.register(engine: flutterViewController.engine)
    
    DisplayBridgeManager.shared.register(with: flutterViewController.engine.binaryMessenger)

    self.isOpaque = false
    self.hasShadow = true
    self.backgroundColor = .clear
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    
    // Register workspace notifications for sleep/wake
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(handleSystemSleep),
        name: NSWorkspace.willSleepNotification,
        object: nil
    )
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(handleSystemWake),
        name: NSWorkspace.didWakeNotification,
        object: nil
    )
    
    // Register distributed notifications for lock/unlock
    DistributedNotificationCenter.default().addObserver(
        self,
        selector: #selector(handleSystemSleep),
        name: NSNotification.Name("com.apple.screenIsLocked"),
        object: nil
    )
    DistributedNotificationCenter.default().addObserver(
        self,
        selector: #selector(handleSystemWake),
        name: NSNotification.Name("com.apple.screenIsUnlocked"),
        object: nil
    )
    
    super.awakeFromNib()
  }

  deinit {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    DistributedNotificationCenter.default().removeObserver(self)
  }

  @objc private func handleSystemSleep() {
    bridgeChannel?.invokeMethod("systemSleep", arguments: nil)
  }

  @objc private func handleSystemWake() {
    bridgeChannel?.invokeMethod("systemWake", arguments: nil)
  }

  private func configureBridge(binaryMessenger: FlutterBinaryMessenger) {
    bridgeChannel = FlutterMethodChannel(
      name: "com.breakmate.desktop/bridge",
      binaryMessenger: binaryMessenger
    )

    bridgeChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "showOverlay":
        OverlayWindowManager.shared.showOverlay(args: call.arguments as? [String: Any])
        result(nil)

      case "hideOverlay":
        let restore = (call.arguments as? [String: Any])?["restoreMainWindow"] as? Bool ?? true
        OverlayWindowManager.shared.hideOverlay(restoreMainWindow: restore)
        result(nil)

      case "showCompanion":
        CompanionWindowManager.shared.showCompanion(args: call.arguments as? [String: Any])
        result(nil)

      case "hideCompanion":
        CompanionWindowManager.shared.hideCompanion()
        result(nil)

      case "setCompanionClickThrough":
        if let args = call.arguments as? [String: Any], let ignore = args["ignore"] as? Bool {
          CompanionWindowManager.shared.setClickThrough(ignore)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing ignore parameter", details: nil))
        }

      case "updateCompanionScale":
        if let args = call.arguments as? [String: Any], let scale = args["scale"] as? Double {
          CompanionWindowManager.shared.updateScale(scale)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing scale", details: nil))
        }

      case "updateCompanionTheme":
        if let args = call.arguments as? [String: Any], let themeId = args["themeId"] as? String {
          CompanionWindowManager.shared.updateTheme(themeId)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing themeId", details: nil))
        }

      case "updateCompanionName":
        if let args = call.arguments as? [String: Any], let petName = args["petName"] as? String {
          CompanionWindowManager.shared.updatePetName(petName)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing petName", details: nil))
        }

      case "triggerCompanionState":
        if let args = call.arguments as? [String: Any], let state = args["state"] as? String {
          CompanionWindowManager.shared.triggerState(state)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing state", details: nil))
        }

      case "setCompanionWandering":
        if let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool {
          CompanionWindowManager.shared.setWanderingEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing enabled", details: nil))
        }

      case "setCompanionFollowMouse":
        if let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool {
          CompanionWindowManager.shared.setFollowMouseEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing enabled", details: nil))
        }

      case "showPipWindow":
        PiPWindowManager.shared.showPipWindow(args: call.arguments as? [String: Any])
        result(nil)

      case "hidePipWindow":
        PiPWindowManager.shared.hidePipWindow()
        result(nil)

      // ── Behavior Engine PAL methods ───────────────────────────────────────

      case "enumerateDisplays", "getCursorPosition", "getVisibleWindows",
           "showConstraintWindow", "hideConstraintWindow", "getIdleTime", "focusApp":
        BehaviorEngineBridge.shared.handle(call, result: result)

      case "getFrontmostApp":
        // Cheap AppKit read — safe and fast on the main thread. Polled every
        // ~10s by the smart-detection background isolate.
        result(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)

      case "isFocusModeActive":
        // No public, stable API exists for reading macOS Focus/DND status
        // across OS versions — reporting "not active" here is honest about
        // that gap and (unlike leaving this unimplemented) avoids throwing
        // a MissingPluginException on every ~10s poll for every user, since
        // `respectFocusMode` defaults on.
        result(false)

      case "setWindowLevel":
        if let args = call.arguments as? [String: Any],
           let level = args["level"] as? String {
          self.setNativeWindowLevel(level)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing level", details: nil))
        }

      case "setPresentationOptions":
        if let args = call.arguments as? [String: Any],
           let hideDock = args["hideDock"] as? Bool,
           let hideMenu = args["hideMenu"] as? Bool {
            if hideDock && hideMenu {
                NSApp.presentationOptions = [.hideDock, .hideMenuBar]
            } else {
                NSApp.presentationOptions = []
            }
            result(nil)
        } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing hideDock or hideMenu", details: nil))
        }

      case "setVisualEffect":
        if let args = call.arguments as? [String: Any], let materialName = args["material"] as? String {
          OverlayWindowManager.shared.updateVisualEffect(materialName: materialName)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing material", details: nil))
        }

      case "setIgnoreMouseEvents":
        if let args = call.arguments as? [String: Any], let ignore = args["ignore"] as? Bool {
          OverlayWindowManager.shared.setClickThrough(ignore)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing ignore parameter", details: nil))
        }

      case "updateOverlayData":
        if let args = call.arguments as? [String: Any] {
          OverlayWindowManager.shared.updateData(args)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing data", details: nil))
        }

      case "checkIsMainEngine":
        result(true)

      case "debugCalendarState":
        self.calendarBridge.debugCalendarState(result: result)

      case "requestCalendarPermissions":
        self.calendarBridge.requestCalendarPermissions(result: result)

      case "hasCalendarPermissions":
        self.calendarBridge.hasCalendarPermissions(result: result)

      case "getCalendarPermissionStatus":
        self.calendarBridge.getCalendarPermissionStatus(result: result)

      case "openCalendarSettings":
        self.calendarBridge.openCalendarSettings(result: result)

      case "getUpcomingCalendarEvents":
        let minutes = (call.arguments as? [String: Any])?["windowMinutes"] as? Int ?? 240
        self.calendarBridge.getUpcomingCalendarEvents(windowMinutes: minutes, result: result)

      case "getCalendars":
        self.calendarBridge.getCalendars(result: result)

      case "getEvents":
        let args = call.arguments as? [String: Any]
        let startMs = args?["startMs"] as? Double ?? 0.0
        let endMs = args?["endMs"] as? Double ?? 0.0
        let calendarIds = args?["calendarIds"] as? [String]
        self.calendarBridge.getEvents(startMs: startMs, endMs: endMs, calendarIds: calendarIds, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }


  private func setNativeWindowLevel(_ level: String) {
    switch level {
    case "screenSaver": self.level = .screenSaver
    case "floating": self.level = .floating
    default: self.level = .normal
    }
  }

  func triggerReopen() {
    bridgeChannel?.invokeMethod("handleReopen", arguments: nil)
  }
}

class DisplayBridgeManager: NSObject, FlutterStreamHandler {
    static let shared = DisplayBridgeManager()
    
    private var eventSink: FlutterEventSink?
    private var lastDisplaysHash: Int = 0
    
    func register(with binaryMessenger: FlutterBinaryMessenger) {
        let methodChannel = FlutterMethodChannel(name: "com.breakmate/display_bridge", binaryMessenger: binaryMessenger)
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getDisplays":
                result(self?.getDisplays())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        let eventChannel = FlutterEventChannel(name: "com.breakmate/display_events", binaryMessenger: binaryMessenger)
        eventChannel.setStreamHandler(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    @objc private func screenParametersChanged() {
        let currentDisplays = getDisplays()
        let currentHash = currentDisplays.map { "\($0["id"] ?? "")-\($0["width"] ?? 0)-\($0["height"] ?? 0)" }.joined().hashValue
        if currentHash != lastDisplaysHash {
            lastDisplaysHash = currentHash
            if let sink = eventSink {
                sink(["type": "display_changed"])
            }
        }
    }
    
    private func getDisplays() -> [[String: Any]] {
        var displays = [[String: Any]]()
        
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let isPrimary = index == 0 // Usually the primary screen is the first one
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            
            // Generate a persistent ID based on display device UUID if possible, but NSScreen doesn't expose it easily.
            // Using localizedName as ID for simplicity, or simply an index string
            var displayId = "Display_\(index)"
            if #available(macOS 10.15, *) {
                displayId = screen.localizedName
            }
            
            let displayData: [String: Any] = [
                "id": displayId,
                "isPrimary": isPrimary,
                "width": frame.width,
                "height": frame.height,
                "pixelRatio": screen.backingScaleFactor,
                "boundsX": frame.origin.x,
                "boundsY": frame.origin.y,
                "boundsWidth": frame.width,
                "boundsHeight": frame.height,
                "workAreaX": visibleFrame.origin.x,
                "workAreaY": visibleFrame.origin.y,
                "workAreaWidth": visibleFrame.width,
                "workAreaHeight": visibleFrame.height,
                "refreshRate": 60.0 // macOS refresh rate is tricky without CGDisplayMode, 60 is a safe default
            ]
            displays.append(displayData)
        }
        
        return displays
    }
}
