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
    // Hidden-but-alive instances kept ready for instant reuse. Spinning up a
    // fresh FlutterEngine per show (cold engine start) is the dominant cost
    // of "why does Preview take ~3s" — after the first show, later shows
    // reuse an already-warm engine instead of paying that cost again.
    private var warmPool: [NSScreen: OverlayInstance] = [:]
    var lastShowArgs: [String: Any]? // Persisted arguments for active overlay
    private var wasMainWindowVisible: Bool = false
    private var lastScreensHash: Int = 0
    private var isObservingSpaces = false
    private var escapeMonitor: Any?
    private var escapePresses: [Date] = []

    private static func currentScreensHash() -> Int {
        NSScreen.screens.map { "\($0.frame)-\($0.visibleFrame)" }.joined().hashValue
    }
    private var showGeneration: Int = 0
    
    struct OverlayInstance {
        let window: OverlayPanel
        let engine: FlutterEngine
        let controller: FlutterViewController
    }
    
    func showOverlay(args: [String: Any]? = nil) {
        self.lastShowArgs = args
        
        let type = args?["type"] as? String ?? args?["overlayType"] as? String ?? "breakScreen"
        let isReminder = type == "quickReminder" || type == "preBreakWarning"
        let isPreview = args?["isPreview"] as? Bool ?? false
        
        if !overlayInstances.isEmpty {
            // Cancel any pending reminder auto-dismiss timer
            showGeneration += 1
            
            // If transitioning from a reminder/pre-break warning to a full break screen, promote the window
            if !isReminder {
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let mainWindow = appDelegate.mainFlutterWindow,
                   !isPreview {
                    wasMainWindowVisible = mainWindow.isVisible
                    mainWindow.orderOut(nil)
                    NativePowerAssertionManager.shared.preventDisplaySleep(reason: "Active Break in Progress")
                }
                
                for instance in overlayInstances.values {
                    instance.window.isReminder = false
                    instance.window.ignoresMouseEvents = false
                    instance.window.orderFrontRegardless()
                    instance.window.makeKey()
                }
            }
            
            if let args = args {
                updateData(args)
            }
            return
        }
        
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let mainWindow = appDelegate.mainFlutterWindow else {
            return
        }
        
        // Only hide main window for real full break screens, not for reminders or previews
        if !isReminder && !isPreview {
            wasMainWindowVisible = mainWindow.isVisible
            mainWindow.orderOut(nil)
            NativePowerAssertionManager.shared.preventDisplaySleep(reason: "Active Break in Progress")
        }
        
        let showOnAllDisplays = args?["showOnAllDisplays"] as? Bool ?? true
        let screens = showOnAllDisplays ? NSScreen.screens : (NSScreen.main.map { [$0] } ?? NSScreen.screens)
        
        for screen in screens {
            let instance: OverlayInstance
            var fadeDelay: TimeInterval = 0
            if let warm = warmPool.removeValue(forKey: screen) {
                prepareReusedInstance(warm, for: screen, args: args)
                instance = warm
                // The reused engine still holds the previous break's frame. Stay
                // invisible until the new data has been delivered and rebuilt,
                // otherwise the old break/skip time flashes before the new one.
                fadeDelay = 0.2
            } else {
                instance = createOverlayInstance(for: screen, args: args)
            }
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
            
            let window = instance.window
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.5
                    window.animator().alphaValue = 1.0
                }
            }
        }

        // Baseline the display layout now. Swiping between Spaces / full-screen
        // apps also posts this notification with an unchanged layout; with a
        // zero baseline that counted as a "change" and tore down the live
        // overlay engines, leaving an opaque black panel with no UI on top.
        lastScreensHash = OverlayWindowManager.currentScreensHash()
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if !isObservingSpaces {
            isObservingSpaces = true
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeSpaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        }

        if !isReminder {
            installEscapeFailsafe()
            scheduleHealthCheck(attempt: 0)
        }

        // Reminders can't become key windows (by design, so they don't steal
        // focus), so they can only be dismissed by the Dart side's own timer.
        // If that Flutter engine ever hangs or drops a message, the overlay
        // would otherwise sit there forever with no way for the user to
        // close it. This is a hard backstop, independent of Dart, so a
        // reminder always goes away on its own.
        // Only quick health reminders (which last 4s) have a hard 6s backstop.
        // Pre-break warnings must run their full countdown (e.g. 20s).
        if type == "quickReminder" {
            showGeneration += 1
            let generation = showGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                guard let self = self, self.showGeneration == generation else { return }
                self.hideOverlay()
            }
        }
    }

    /// Last time a full overlay was dismissed; used to ignore the spurious
    /// "reopen" macOS sends when the overlay panels disappear.
    var lastHideTime: Date = .distantPast
    var isOverlayShowing: Bool { !overlayInstances.isEmpty }

    func hideOverlay(restoreMainWindow: Bool = true) {
        showGeneration += 1
        lastHideTime = Date()
        removeEscapeFailsafe()
        NativePowerAssertionManager.shared.releaseDisplaySleep()
        if overlayInstances.isEmpty { return }

        let entries = overlayInstances
        overlayInstances.removeAll()
        let instances = Array(entries.values)

        let shouldRestore = restoreMainWindow && wasMainWindowVisible
        wasMainWindowVisible = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            for instance in instances {
                instance.window.animator().alphaValue = 0.0
            }
        }, completionHandler: {
            // Restore main window visibility only if requested and was visible before
            // Never activate the app here: a finished/skipped break must not pull
            // BreakMate in front of whatever the user is working in. If the app
            // is already active (user was in BreakMate) bring the window back
            // normally; otherwise put it behind other windows, ready for when
            // the user explicitly opens the app.
            if shouldRestore,
               let appDelegate = NSApp.delegate as? AppDelegate,
               let mainWindow = appDelegate.mainFlutterWindow {
                // Never bring it to front: an ended break must not open BreakMate.
                mainWindow.orderBack(nil)
            }

            for instance in instances {
                // Already reused by a new show during the fade-out: leave it alone.
                if self.overlayInstances.values.contains(where: { $0.window === instance.window }) { continue }
                instance.window.orderOut(nil)
                instance.window.ignoresMouseEvents = false
                let channel = FlutterMethodChannel(name: "com.breakmate.desktop/bridge", binaryMessenger: instance.engine.binaryMessenger)
                channel.invokeMethod("resetOverlay", arguments: nil)
            }
        })

        // Keep the engines alive, hidden, for instant reuse next time —
        // see `warmPool`. They're only ever actually torn down when the
        // screen configuration changes (their window frames would be
        // stale) or the app is quitting.
        for (screen, instance) in entries {
            warmPool[screen] = instance
        }

        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if isObservingSpaces {
            isObservingSpaces = false
            NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        }
    }

    /// Native recovery that never depends on Flutter. A full break overlay is an
    /// opaque black panel, so if its engine hangs or never receives data the
    /// screen would be black and undismissable. Ask each engine whether it has
    /// rendered; re-send the data once, then give up and dismiss the break.
    private func scheduleHealthCheck(attempt: Int) {
        let generation = showGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, self.showGeneration == generation,
                  !self.overlayInstances.isEmpty,
                  !(self.overlayInstances.values.first?.window.isReminder ?? true) else { return }

            let instances = Array(self.overlayInstances.values)
            var pending = instances.count
            var allReady = true
            var answered = false

            let finish = { [weak self] in
                guard let self = self, self.showGeneration == generation, !answered else { return }
                answered = true
                if allReady { return }
                if attempt == 0, let args = self.lastShowArgs {
                    self.updateData(args)
                    self.scheduleHealthCheck(attempt: 1)
                } else {
                    NSLog("[Overlay] Break overlay never rendered; dismissing it")
                    self.emergencyDismiss()
                }
            }

            for instance in instances {
                let channel = FlutterMethodChannel(name: "com.breakmate.desktop/bridge", binaryMessenger: instance.engine.binaryMessenger)
                channel.invokeMethod("isReady", arguments: nil) { value in
                    DispatchQueue.main.async {
                        if (value as? Bool) != true { allReady = false }
                        pending -= 1
                        if pending == 0 { finish() }
                    }
                }
            }
            // An engine that is hung never answers at all.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if pending > 0 { allReady = false; finish() }
            }
        }
    }

    /// Hide the overlay and tell the main app the break was skipped.
    func emergencyDismiss() {
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let mainWindow = appDelegate.mainFlutterWindow as? MainFlutterWindow {
            mainWindow.bridgeChannel?.invokeMethod("skipBreak", arguments: nil)
        }
        hideOverlay()
    }

    /// Pressing Escape three times quickly always closes a full break overlay,
    /// even in strict mode or when the Flutter UI is dead.
    private func installEscapeFailsafe() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, event.keyCode == 53 else { return event }
            let now = Date()
            self.escapePresses = self.escapePresses.filter { now.timeIntervalSince($0) < 2 } + [now]
            if self.escapePresses.count >= 3 {
                self.escapePresses.removeAll()
                self.emergencyDismiss()
            }
            return event
        }
    }

    private func removeEscapeFailsafe() {
        if let monitor = escapeMonitor { NSEvent.removeMonitor(monitor) }
        escapeMonitor = nil
        escapePresses.removeAll()
    }

    /// The user switched Space / full-screen app while an overlay is up. Put the
    /// panels back in front on the new Space so the break UI is shown there
    /// instead of leaving a stale, empty panel behind.
    @objc private func activeSpaceChanged() {
        for instance in overlayInstances.values {
            instance.window.orderFrontRegardless()
            if !instance.window.isReminder { instance.window.makeKey() }
        }
    }

    private func destroyInstance(_ instance: OverlayInstance) {
        instance.window.orderOut(nil)
        instance.window.contentViewController = nil
        instance.window.contentView = nil

        let channel = FlutterMethodChannel(name: "com.breakmate.desktop/bridge", binaryMessenger: instance.engine.binaryMessenger)
        channel.setMethodCallHandler(nil)

        IpcBridgeManager.shared.unregister(engine: instance.engine)
        instance.engine.shutDownEngine()
    }

    /// Fully tears down every warm/active engine — call only when their
    /// window frames are stale (screen configuration changed) or the app
    /// is quitting. Everyday hide/show should never reach this; that's the
    /// whole point of `warmPool`.
    func destroyAllInstances() {
        NativePowerAssertionManager.shared.releaseDisplaySleep()
        for instance in overlayInstances.values { destroyInstance(instance) }
        for instance in warmPool.values { destroyInstance(instance) }
        overlayInstances.removeAll()
        warmPool.removeAll()
    }
    
    func setClickThrough(_ enabled: Bool) {
        for instance in overlayInstances.values {
            instance.window.ignoresMouseEvents = enabled
        }
    }
    
    func updateData(_ data: [String: Any]) {
        let type = data["type"] as? String ?? data["overlayType"] as? String ?? ""
        if !type.isEmpty {
            let isReminder = type == "quickReminder" || type == "preBreakWarning"
            for instance in overlayInstances.values {
                instance.window.isReminder = isReminder
                if !isReminder {
                    instance.window.ignoresMouseEvents = false
                }
            }
        }
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
        let screensHash = OverlayWindowManager.currentScreensHash()
        if screensHash == lastScreensHash {
            return
        }
        lastScreensHash = screensHash
        
        // A real display change means every window frame (active or
        // pooled) is stale — unlike a normal hide, these can't be kept
        // warm for reuse, they have to be rebuilt against the new screens.
        let savedArgs = self.lastShowArgs
        destroyAllInstances()
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
                    mainWindow.bridgeChannel?.invokeMethod("completeBreak", arguments: call.arguments)
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

    /// Reuses an already-warm instance pulled from `warmPool` for a new
    /// show — same idea as `createOverlayInstance`'s setup, minus creating
    /// a new window/engine (that's the whole point: no cold engine start,
    /// no waiting on a fresh Dart isolate to boot). Its method channel
    /// handler is already registered from when it was first created, so a
    /// single `updateOverlayData` call is enough — no need for the
    /// redundant delayed broadcast `createOverlayInstance` sends to catch
    /// a still-warming-up engine.
    private func prepareReusedInstance(_ instance: OverlayInstance, for screen: NSScreen, args: [String: Any]?) {
        let isTransparent = args?["isTransparent"] as? Bool ?? false
        instance.window.backgroundColor = isTransparent ? NSColor.clear : NSColor.black
        instance.window.isOpaque = !isTransparent
        instance.window.ignoresMouseEvents = args?["ignoreMouseEvents"] as? Bool ?? false
        instance.controller.backgroundColor = isTransparent ? NSColor.clear : NSColor.black
        instance.window.setFrame(screen.frame, display: true)

        var initialArgs = args ?? [:]
        var displayId = "Display_unknown"
        if #available(macOS 10.15, *) {
            displayId = screen.localizedName
        }
        initialArgs["displayId"] = displayId
        initialArgs["boundsWidth"] = screen.frame.width
        initialArgs["boundsHeight"] = screen.frame.height

        let channel = FlutterMethodChannel(name: "com.breakmate.desktop/bridge", binaryMessenger: instance.engine.binaryMessenger)
        channel.invokeMethod("updateOverlayData", arguments: initialArgs)
    }
}

class MainFlutterWindow: NSWindow {
  static weak var shared: MainFlutterWindow?
  fileprivate var bridgeChannel: FlutterMethodChannel?

  // Dedicated bridge for all EventKit / calendar operations.
  // Declared as a lazy var so it is created after the window is fully set up.
  private lazy var calendarBridge = CalendarBridge()

  func notifyPipBackgroundStyleChanged(_ style: String) {
    bridgeChannel?.invokeMethod("onPipBackgroundStyleChanged", arguments: ["style": style])
  }

  override func awakeFromNib() {
    MainFlutterWindow.shared = self
    // Open on whichever Space the user is on (including full-screen apps)
    // instead of switching back to the Space the window was created in.
    self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
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
          PiPFlutterWindowManager.shared.updateTheme(themeId: themeId, extra: args)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing themeId", details: nil))
        }

      case "updateCompanionName":
        if let args = call.arguments as? [String: Any], let petName = args["petName"] as? String {
          CompanionWindowManager.shared.updatePetName(petName)
          PiPFlutterWindowManager.shared.updatePetName(petName)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing petName", details: nil))
        }

      case "triggerCompanionState":
        if let args = call.arguments as? [String: Any], let state = args["state"] as? String {
          CompanionWindowManager.shared.triggerState(state)
          PiPFlutterWindowManager.shared.triggerState(state)
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
          PiPFlutterWindowManager.shared.syncSettings(["followMouse": enabled])
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing enabled", details: nil))
        }

      case "showPipWindow":
        PiPFlutterWindowManager.shared.showPipWindow(args: call.arguments as? [String: Any])
        result(nil)

      case "hidePipWindow":
        PiPFlutterWindowManager.shared.hidePipWindow()
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

  /// Brings the window to the user's current Space (even over a full-screen
  /// app) instead of letting macOS switch to the Space it was last shown on.
  func showOnCurrentSpace() {
    collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    if isMiniaturized { deminiaturize(nil) }
    // `moveToActiveSpace` only applies when the window is ordered in, so pull
    // it off its old Space first.
    if isVisible && !isOnActiveSpace { orderOut(nil) }
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    orderFrontRegardless()
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
