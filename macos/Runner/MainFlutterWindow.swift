import Cocoa
import FlutterMacOS

class OverlayPanel: NSPanel {
    var isReminder: Bool = false
    var placedOrigin: NSPoint?
    
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
    private var compactActive = false
    fileprivate var switchedToImmersive = false
    // Where the user dragged the pre-break warning, relative to its screen.
    private var warningOffset: NSPoint?

    private static func currentScreensHash() -> Int {
        NSScreen.screens.map { "\($0.frame)" }.joined().hashValue
    }
    private var showGeneration: Int = 0
    
    struct OverlayInstance {
        let window: OverlayPanel
        let engine: FlutterEngine
        let controller: FlutterViewController
    }
    
    func showOverlay(args inArgs: [String: Any]? = nil) {
        var args = inArgs
        let isRefresh = args?["refresh"] as? Bool == true
        // Dart keeps refreshing with the original compact mode after the user opened the full view.
        if !isRefresh { switchedToImmersive = false }
        if switchedToImmersive { args?["windowMode"] = "immersive" }
        // A data refresh racing a dismissal must not rebuild the panels the user just closed.
        if args?["refresh"] as? Bool == true && overlayInstances.isEmpty { return }
        self.lastShowArgs = args
        
        let type = args?["type"] as? String ?? args?["overlayType"] as? String ?? "breakScreen"
        if args?["windowMode"] as? String == "compact" && type == "breakScreen" {
            showCompact(args)
            return
        }
        if compactActive {
            showGeneration += 1
            destroyAllInstances()
        }
        let isReminder = type == "quickReminder" || type == "preBreakWarning"
        let isPreview = args?["isPreview"] as? Bool ?? false
        let showOnAllDisplays = args?["showOnAllDisplays"] as? Bool ?? true
        let screens = showOnAllDisplays ? NSScreen.screens : (NSScreen.main.map { [$0] } ?? NSScreen.screens)
        
        if !overlayInstances.isEmpty {
            // Cancel any pending reminder auto-dismiss timer
            showGeneration += 1
            
            // If transitioning from a reminder/pre-break warning to a full break screen, promote the window
            if !isReminder {
                rememberWarningPosition()
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let mainWindow = appDelegate.mainFlutterWindow,
                   !isPreview {
                    wasMainWindowVisible = mainWindow.isVisible
                    mainWindow.orderOut(nil)
                    NativePowerAssertionManager.shared.preventDisplaySleep(reason: "Active Break in Progress")
                }
                
                for (screen, instance) in overlayInstances {
                    instance.window.setFrame(screen.frame, display: true)
                    instance.window.isReminder = false
                    instance.window.ignoresMouseEvents = false
                    instance.window.orderFrontRegardless()
                    instance.window.makeKey()
                }
                // A reminder/pre-break warning may have opened on one display only.
                for screen in screens where overlayInstances[screen] == nil {
                    present(screen, args: args, isReminder: false)
                }
                installEscapeFailsafe()
                scheduleHealthCheck(attempt: 0)
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
        
        for screen in screens {
            present(screen, args: args, isReminder: isReminder)
        }

        // Baseline the display layout now. Swiping between Spaces / full-screen
        // apps also posts this notification with an unchanged layout; with a
        // zero baseline that counted as a "change" and tore down the live
        // overlay engines, leaving an opaque black panel with no UI on top.
        lastScreensHash = OverlayWindowManager.currentScreensHash()
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
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
        // A quick reminder lasts 4s; a pre-break warning lasts its countdown.
        let ttl: Double?
        switch type {
        case "quickReminder": ttl = 6
        case "preBreakWarning": ttl = ((args?["secondsRemaining"] as? NSNumber)?.doubleValue ?? 3) + 5
        default: ttl = nil
        }
        if let ttl = ttl {
            showGeneration += 1
            let generation = showGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + ttl) { [weak self] in
                guard let self = self, self.showGeneration == generation else { return }
                // The main app tracks overlay visibility, so it must hear about this too.
                (MainFlutterWindow.shared)?.bridgeChannel?.invokeMethod("hideOverlay", arguments: nil)
                self.hideOverlay()
            }
        }
    }

    private func compactFrame(on screen: NSScreen, args: [String: Any]?) -> NSRect {
        let margin: CGFloat = 16
        let w = CGFloat((args?["compactWidth"] as? NSNumber)?.doubleValue ?? 360) + 2 * margin
        let h = CGFloat((args?["compactHeight"] as? NSNumber)?.doubleValue ?? 244) + 2 * margin
        let area = screen.visibleFrame
        let corner = args?["compactCorner"] as? String ?? "bottomRight"
        let x = corner.hasSuffix("Left") ? area.minX : area.maxX - w
        let y = corner.hasPrefix("top") ? area.maxY - h : area.minY
        return NSRect(x: x, y: y, width: w, height: h)
    }

    private func showCompact(_ args: [String: Any]?) {
        if compactActive, let (screen, instance) = overlayInstances.first {
            instance.window.setFrame(compactFrame(on: screen, args: args), display: true)
            updateData(args ?? [:])
            return
        }
        showGeneration += 1
        if !overlayInstances.isEmpty {
            removeEscapeFailsafe()
            destroyAllInstances()
        }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first else { return }

        var initialArgs = args ?? [:]
        initialArgs["isTransparent"] = true
        initialArgs["ignoreMouseEvents"] = false
        let instance = createOverlayInstance(for: screen, args: initialArgs)
        let window = instance.window
        window.isReminder = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.setFrame(compactFrame(on: screen, args: args), display: true)
        window.alphaValue = 0
        overlayInstances[screen] = instance
        compactActive = true
        window.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        }

        lastScreensHash = OverlayWindowManager.currentScreensHash()
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if !isObservingSpaces {
            isObservingSpaces = true
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeSpaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        }
    }

    private func rememberWarningPosition() {
        for (screen, instance) in overlayInstances {
            let origin = instance.window.frame.origin
            if let placed = instance.window.placedOrigin, placed != origin {
                warningOffset = NSPoint(x: origin.x - screen.frame.minX, y: origin.y - screen.frame.minY)
            }
            instance.window.placedOrigin = nil
        }
    }

    private func present(_ screen: NSScreen, args: [String: Any]?, isReminder: Bool) {
        // A panel already tracked for this screen would be orphaned (visible, never hidden) if overwritten.
        if let old = overlayInstances.removeValue(forKey: screen) { destroyInstance(old) }
        let instance: OverlayInstance
        var fadeDelay: TimeInterval = 0
        if let warm = warmPool.removeValue(forKey: screen) {
            prepareReusedInstance(warm, for: screen, args: args)
            instance = warm
            // The reused engine still holds the previous break's frame. Stay
            // invisible until the new data has been delivered and rebuilt.
            fadeDelay = 0.2
        } else {
            instance = createOverlayInstance(for: screen, args: args)
        }
        instance.window.isReminder = isReminder
        if args?["type"] as? String == "preBreakWarning" {
            // Card-sized window instead of full-screen so the Skip button is clickable without blocking the screen.
            let size = NSSize(width: args?["warningWidth"] as? Double ?? 380, height: args?["warningHeight"] as? Double ?? 100)
            let f = screen.frame
            let offset = warningOffset ?? NSPoint(x: (f.width - size.width) / 2, y: (f.height - size.height) / 2)
            let x = f.minX + min(max(offset.x, 0), f.width - size.width)
            let y = f.minY + min(max(offset.y, 0), f.height - size.height)
            instance.window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
            instance.window.placedOrigin = instance.window.frame.origin
            instance.window.ignoresMouseEvents = false
        }
        overlayInstances[screen] = instance
        // Zero-duration animator write also cancels a fade-out still running from the previous hide.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            instance.window.animator().alphaValue = 0.0
        }

        // Full screens must become key to receive Escape / any-key dismiss;
        // the panel is non-activating so this does not steal app focus.
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

    /// Last time a full overlay was dismissed; used to ignore the spurious
    /// "reopen" macOS sends when the overlay panels disappear.
    var lastHideTime: Date = .distantPast
    var isOverlayShowing: Bool { !overlayInstances.isEmpty }

    func hideOverlay(restoreMainWindow: Bool = true) {
        rememberWarningPosition()
        showGeneration += 1
        lastHideTime = Date()
        switchedToImmersive = false
        removeEscapeFailsafe()
        NativePowerAssertionManager.shared.releaseDisplaySleep()
        if overlayInstances.isEmpty {
            for instance in warmPool.values { instance.window.orderOut(nil) }
            return
        }

        let wasCompact = compactActive
        compactActive = false
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
                if wasCompact { continue }
                instance.window.ignoresMouseEvents = false
                let channel = FlutterMethodChannel(name: "com.breakmate.desktop/bridge", binaryMessenger: instance.engine.binaryMessenger)
                channel.invokeMethod("resetOverlay", arguments: nil)
            }
        })

        // The fade-out completion can be skipped (Space switch, busy main
        // thread). Never leave an opaque panel behind: force-hide regardless.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            for instance in instances where !self.overlayInstances.values.contains(where: { $0.window === instance.window }) {
                instance.window.orderOut(nil)
                instance.window.alphaValue = 0.0
                if wasCompact { self.destroyInstance(instance) }
            }
        }

        // Keep the engines alive, hidden, for instant reuse next time —
        // see `warmPool`. They're only ever actually torn down when the
        // screen configuration changes (their window frames would be
        // stale) or the app is quitting.
        if !wasCompact {
            for (screen, instance) in entries {
                warmPool[screen] = instance
            }
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
        compactActive = false
    }
    
    func setClickThrough(_ enabled: Bool) {
        for instance in overlayInstances.values {
            instance.window.ignoresMouseEvents = enabled
        }
    }
    
    func updateData(_ data: [String: Any]) {
        let type = data["type"] as? String ?? data["overlayType"] as? String ?? ""
        if !type.isEmpty && !compactActive {
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
        var savedArgs = self.lastShowArgs
        savedArgs?["refresh"] = nil
        destroyAllInstances()
        let generation = showGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Dismissed (or replaced) during the rebuild: don't resurrect it.
            guard self.showGeneration == generation else { return }
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
        
        channel.setMethodCallHandler { [weak window] call, result in
            switch call.method {
            case "startDragging":
                if let window = window, window.isReminder, let event = NSApp.currentEvent {
                    window.performDrag(with: event)
                }
                result(nil)
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
                    mainWindow.bridgeChannel?.invokeMethod("skipBreak", arguments: call.arguments)
                }
                OverlayWindowManager.shared.hideOverlay()
                result(nil)
            case "snoozeBreak":
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let mainWindow = appDelegate.mainFlutterWindow as? MainFlutterWindow {
                    mainWindow.bridgeChannel?.invokeMethod("snoozeBreak", arguments: nil)
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
            case "openImmersive":
                var args = OverlayWindowManager.shared.lastShowArgs ?? [:]
                args["windowMode"] = "immersive"
                args["refresh"] = nil
                DispatchQueue.main.async {
                    OverlayWindowManager.shared.showOverlay(args: args)
                    OverlayWindowManager.shared.switchedToImmersive = true
                }
                result(nil)
            case "setIgnoreMouseEvents":
                if let args = call.arguments as? [String: Any], let ignore = args["ignore"] as? Bool {
                    OverlayWindowManager.shared.setClickThrough(ignore)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing ignore parameter", details: nil))
                }
            case "enumerateDisplays", "getCursorPosition", "getVisibleWindows",
                 "showConstraintWindow", "hideConstraintWindow", "getIdleTime", "getSessionState", "focusApp":
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
    // A debug launch inherits the terminal's cwd; when macOS denies access to
    // it (e.g. a protected folder), Dart's Uri.base / package:path throw and
    // storage init fails. Start from a directory we can always read.
    FileManager.default.changeCurrentDirectoryPath(NSHomeDirectory())
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
    // Install before launch completes so clicks on previously delivered update
    // notifications can also reopen Sparkle after the app was quit.
    (NSApp.delegate as? AppDelegate)?.installUpdateNotificationDelegate()
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
    
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(handleSessionInactive),
        name: NSWorkspace.sessionDidResignActiveNotification,
        object: nil
    )
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(handleSessionActive),
        name: NSWorkspace.sessionDidBecomeActiveNotification,
        object: nil
    )

    DistributedNotificationCenter.default().addObserver(
        self,
        selector: #selector(handleSessionLocked),
        name: NSNotification.Name("com.apple.screenIsLocked"),
        object: nil
    )
    DistributedNotificationCenter.default().addObserver(
        self,
        selector: #selector(handleSessionUnlocked),
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
    bridgeChannel?.invokeMethod("systemSleep", arguments: Int(Date().timeIntervalSince1970 * 1000))
  }

  @objc private func handleSystemWake() {
    bridgeChannel?.invokeMethod("systemWake", arguments: nil)
  }

  @objc private func handleSessionLocked() { bridgeChannel?.invokeMethod("sessionLocked", arguments: nil) }
  @objc private func handleSessionUnlocked() { bridgeChannel?.invokeMethod("sessionUnlocked", arguments: nil) }
  @objc private func handleSessionInactive() { bridgeChannel?.invokeMethod("sessionInactive", arguments: nil) }
  @objc private func handleSessionActive() { bridgeChannel?.invokeMethod("sessionActive", arguments: nil) }

  private func configureBridge(binaryMessenger: FlutterBinaryMessenger) {
    bridgeChannel = FlutterMethodChannel(
      name: "com.breakmate.desktop/bridge",
      binaryMessenger: binaryMessenger
    )

    bridgeChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "armLiveTrayMenu":
        LiveTrayMenuText.shared.arm()
        result(nil)

      case "setNightShift":
        result(NightShift.set(call.arguments as? Bool ?? false))

      case "updateTrayMenu":
        result(LiveTrayMenuText.shared.update(call.arguments as? [Any] ?? []))

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
           "showConstraintWindow", "hideConstraintWindow", "getIdleTime", "getSessionState", "focusApp":
        BehaviorEngineBridge.shared.handle(call, result: result)

      case "getFrontmostApp":
        // Cheap AppKit read — safe and fast on the main thread. Polled every
        // ~10s by the smart-detection background isolate.
        result(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)

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


/// Keeps the countdown rows of the tray menu current while it is open. The
/// menu itself is shown by the tray plugin; this only watches for it opening
/// and rewrites item titles in place.
final class LiveTrayMenuText: NSObject {
  static let shared = LiveTrayMenuText()
  private var armed = false
  private var tracked: NSMenu?

  override init() {
    super.init()
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(began(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
    nc.addObserver(self, selector: #selector(ended(_:)), name: NSMenu.didEndTrackingNotification, object: nil)
  }

  func arm() {
    armed = true
    tracked = nil
  }

  @objc private func began(_ n: Notification) {
    if armed, tracked == nil { tracked = n.object as? NSMenu }
  }

  @objc private func ended(_ n: Notification) {
    if let m = tracked, (n.object as? NSMenu) === m {
      tracked = nil
      armed = false
    }
  }

  /// Returns false once the menu has closed so the sender can stop.
  func update(_ labels: [Any]) -> Bool {
    guard armed else { return false }
    guard let m = tracked, m.items.count == labels.count else { return true }
    for (item, label) in zip(m.items, labels) {
      if let text = label as? String, !item.isSeparatorItem, item.title != text {
        item.title = text
      }
    }
    return true
  }
}

/// Night Shift has no public API; this drives the private CoreBrightness
/// client resolved at runtime, so a missing/changed class just returns false.
enum NightShift {
  static func set(_ on: Bool) -> Bool {
    guard
      let bundle = Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework"),
      bundle.load(),
      let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type
    else { return false }
    let client = cls.init()
    let sel = NSSelectorFromString("setEnabled:")
    guard client.responds(to: sel) else { return false }
    typealias Fn = @convention(c) (AnyObject, Selector, Bool) -> Bool
    return unsafeBitCast(client.method(for: sel), to: Fn.self)(client, sel, on)
  }
}
