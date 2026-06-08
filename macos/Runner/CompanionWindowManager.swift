import Cocoa
import FlutterMacOS
import IOKit.ps

class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

class CompanionWindowManager: NSObject {
    static let shared = CompanionWindowManager()
    
    private var instance: CompanionInstance?
    private var isSettingUp = false
    
    private var userClickThrough = false
    private var followMouseEnabled = false
    private var followMouseTimer: Timer?
    
    private var energyStatusTimer: Timer?
    private var lastEnergyStatus: [String: Any] = [:]
    
    // Stores the initial spawn args so Flutter can pull them after its method handler registers
    private var pendingInitialArgs: [String: Any]?
    
    private var catOffsetFromBottom: CGFloat = 40.0
    private var catOffsetFromLeft: CGFloat = 175.0
    private var mouseChaseActive = false
    private var mouseChaseSpeed: Double = 300.0
    
    struct CompanionInstance {
        let window: CompanionPanel
        let engine: FlutterEngine
        let controller: FlutterViewController
    }
    
    private override init() {
        super.init()
    }
    
    /// Spawns the transparent, borderless floating companion panel on screen.
    func showCompanion(args: [String: Any]?) {
        guard instance == nil && !isSettingUp else {
            if let args = args {
                updateCompanionParams(args: args)
            }
            return
        }
        
        isSettingUp = true
        
        // Aggressively close any orphaned CompanionPanel windows before creating a new one
        for w in NSApp.windows {
            if let panel = w as? CompanionPanel {
                panel.orderOut(nil)
                panel.contentViewController = nil
                panel.contentView = nil
            }
        }
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Fullscreen overlay frame spanning the screen's visible area
        let frame = screenFrame
        
        let window = CompanionPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
        
        // Unconditional click-through for zero user work disruption
        window.ignoresMouseEvents = true
        
        // Spawn a fresh, dedicated Flutter engine with its own Dart isolate.
        let engine = FlutterEngine(
            name: "CompanionEngine",
            project: nil,
            allowHeadlessExecution: true
        )
        engine.run(withEntrypoint: "companionMain")
        RegisterSecondaryPlugins(registry: engine)
        
        IpcBridgeManager.shared.register(engine: engine)
        
        finishCompanionSetup(
            engine: engine,
            window: window,
            frame: frame,
            args: args
        )
    }
    
    private func finishCompanionSetup(
        engine: FlutterEngine,
        window: CompanionPanel,
        frame: NSRect,
        args: [String: Any]?
    ) {
        isSettingUp = false
        
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        controller.backgroundColor = .clear
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        controller.view.autoresizingMask = [.width, .height]
        controller.view.frame = NSRect(origin: .zero, size: frame.size)
        
        window.contentView = controller.view
        
        instance = CompanionInstance(window: window, engine: engine, controller: controller)
        
        // Store initial args so Flutter can pull them via getInitialSettings after its
        // method handler registers (avoids race condition where push arrives too early)
        pendingInitialArgs = args
        
        // Setup MethodChannel for native drag tracking and overlay synchronization
        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/companion_data",
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "syncCompanionSettings" {
                // With stationary fullscreen window, we ignore frame adjustments from Flutter
                result(nil)
            } else if call.method == "getInitialSettings" {
                // Flutter pulls its initial configuration on startup to avoid the push-race
                var response = self?.pendingInitialArgs ?? [:]
                let energyStatus = self?.getSystemEnergyStatus() ?? [:]
                for (key, value) in energyStatus {
                    response[key] = value
                }
                result(response)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        // Setup MethodChannel for behavior engine bridge
        let bridgeChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/bridge",
            binaryMessenger: engine.binaryMessenger
        )
        bridgeChannel.setMethodCallHandler { call, result in
            BehaviorEngineBridge.shared.handle(call, result: result)
        }
        
        // Also attempt an immediate push; Flutter may already be ready if it initialized fast
        if let args = args {
            updateCompanionParams(args: args)
        }
        
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Fades in the window after a brief delay (150ms) to ensure the Flutter engine
        // has finished warm-up and drawn its initial transparent state.
        // This avoids a solid black full-screen flash at startup!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                window.animator().alphaValue = 1.0
            }
        }
        
        // Start the energy status tracking timer
        startEnergyStatusTimer()
    }
    
    private func clampFrameToScreen(_ frame: NSRect, for window: NSWindow) -> NSRect {
        var clampedFrame = frame
        let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
        var targetScreen = window.screen
        for s in NSScreen.screens {
            if s.frame.contains(centerPoint) {
                targetScreen = s
                break
            }
        }
        
        if let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first {
            let screenFrame = screen.frame // Allow moving around the entire display (Menu Bar & Dock included)
            
            // Keep window horizontally within screen bounds
            if clampedFrame.origin.x < screenFrame.minX {
                clampedFrame.origin.x = screenFrame.minX
            } else if clampedFrame.origin.x + clampedFrame.size.width > screenFrame.maxX {
                clampedFrame.origin.x = screenFrame.maxX - clampedFrame.size.width
            }
            
            // Keep window vertically within screen bounds
            if clampedFrame.origin.y < screenFrame.minY {
                clampedFrame.origin.y = screenFrame.minY
            } else if clampedFrame.origin.y + clampedFrame.size.height > screenFrame.maxY {
                clampedFrame.origin.y = screenFrame.maxY - clampedFrame.size.height
            }
        }
        return clampedFrame
    }
    
    private func moveCompanionWindow(dx: Double, dy: Double) {
        // Fullscreen overlay window is stationary, so we do not shift the native frame.
    }
    
    /// Dynamic companion updater. Passes changes down to the companion Flutter engine.
    private func updateCompanionParams(args: [String: Any]) {
        guard let instance = instance else { return }
        
        if let clickThrough = args["clickThrough"] as? Bool {
            userClickThrough = clickThrough
        }
        instance.window.ignoresMouseEvents = true
        
        if let followMouse = args["followMouse"] as? Bool {
            setFollowMouseEnabled(followMouse)
        }
        
        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/companion_data",
            binaryMessenger: instance.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: args)
    }
    
    /// Hides and terminates the companion overlay processes cleanly.
    func hideCompanion() {
        isSettingUp = false
        guard let inst = instance else { return }
        
        inst.window.orderOut(nil)
        inst.window.contentViewController = nil
        inst.window.contentView = nil
        
        let channel = FlutterMethodChannel(name: "com.breakmate.desktop/companion_data", binaryMessenger: inst.engine.binaryMessenger)
        channel.setMethodCallHandler(nil)
        
        IpcBridgeManager.shared.unregister(engine: inst.engine)
        inst.engine.shutDownEngine()
        instance = nil
        
        // Reset mouse follow states cleanly to prevent stuck timers/flags when re-created
        followMouseTimer?.invalidate()
        followMouseTimer = nil
        followMouseEnabled = false
        mouseChaseActive = false
        
        // Reset energy status timer and states cleanly
        energyStatusTimer?.invalidate()
        energyStatusTimer = nil
        lastEnergyStatus = [:]
    }
    
    /// Dynamic click-through modifier.
    func setClickThrough(_ enabled: Bool) {
        userClickThrough = enabled
        instance?.window.ignoresMouseEvents = true
    }
    
    /// Swaps themes dynamically at runtime.
    func updateTheme(_ themeId: String) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["themeId": themeId])
    }

    /// Updates companion metadata shown by the Flutter companion isolate.
    func updatePetName(_ petName: String) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["petName": petName])
    }
    
    /// Modifies companion scaling factor and adjusts container bounds accordingly.
    func updateScale(_ scale: Double) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["scale": scale])
    }

    /// Triggers a dynamic behavioral animation state on the secondary Flame engine.
    func triggerState(_ state: String) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["state": state])
    }

    /// Sets whether wandering AI is enabled on the secondary Flame engine.
    func setWanderingEnabled(_ enabled: Bool) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["wanderingEnabled": enabled])
    }
    
    /// Updates window level for always-on-top behavior
    func setAlwaysOnTop(_ enabled: Bool) {
        instance?.window.level = enabled ? .floating : .normal
    }
    
    /// Moves the companion window to a specific position (disabled for fullscreen)
    func setPosition(x: Double, y: Double) {
        // Fullscreen overlay window is stationary
    }
    
    /// Resizes the companion window (disabled for fullscreen)
    func setSize(width: Double, height: Double) {
        // Fullscreen overlay window matches visible frame
    }
    
    /// Enables or disables cursor tracking mode
    func setFollowMouseEnabled(_ enabled: Bool) {
        guard followMouseEnabled != enabled else { return }
        followMouseEnabled = enabled
        
        if enabled {
            instance?.window.ignoresMouseEvents = true
            
            followMouseTimer?.invalidate()
            followMouseTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
                self?.updateMouseFollowing()
            }
        } else {
            followMouseTimer?.invalidate()
            followMouseTimer = nil
            mouseChaseActive = false
            
            if let inst = instance {
                inst.window.ignoresMouseEvents = true
            }
            
            // Notify Flame that cursor chase mode is inactive
            if let inst = instance {
                let channel = FlutterMethodChannel(
                    name: "com.breakmate.desktop/companion_data",
                    binaryMessenger: inst.engine.binaryMessenger
                )
                channel.invokeMethod("syncCompanionSettings", arguments: [
                    "mouseFollow": [
                        "enabled": false
                    ]
                ])
            }
        }
    }
    
    private func updateMouseFollowing() {
        guard let inst = instance else { return }
        
        let mousePos = NSEvent.mouseLocation
        
        // Find screen that currently holds the mouse cursor
        var targetScreen: NSScreen?
        for s in NSScreen.screens {
            if s.frame.contains(mousePos) {
                targetScreen = s
                break
            }
        }
        
        let screen = targetScreen ?? inst.window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return }
        
        let screenFrame = screen.visibleFrame
        
        // --- Multi-display Support: Move window to the screen where the mouse is ---
        if inst.window.screen != screen {
            inst.window.setFrame(screenFrame, display: true, animate: false)
            // Ensure the view within the controller also matches new bounds
            inst.controller.view.frame = NSRect(origin: .zero, size: screenFrame.size)
        }
        
        // Calculate coordinates relative to the visible workspace area
        let relativeMouseX = mousePos.x - screenFrame.minX
        let relativeMouseY = mousePos.y - screenFrame.minY
        
        let localMouseX = relativeMouseX
        let localMouseY = screenFrame.height - relativeMouseY
        
        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        
        // Consistently update Flutter with current tracking info so Flutter's FSM can make decisions
        channel.invokeMethod("syncCompanionSettings", arguments: [
            "mouseFollow": [
                "enabled": true,
                "mouseX": Double(localMouseX),
                "mouseY": Double(localMouseY)
            ]
        ])
    }
    
    // MARK: - Adaptive FPS / Battery & Focus Throttling
    
    private func getSystemEnergyStatus() -> [String: Any] {
        let onBattery = checkIsOnBattery()
        let appActive = NSApp.isActive
        var lowPowerMode = false
        if #available(macOS 12.0, *) {
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        return [
            "isOnBattery": onBattery,
            "isAppActive": appActive,
            "isLowPowerMode": lowPowerMode
        ]
    }
    
    private func checkIsOnBattery() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeUnretainedValue() as Array
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                if let state = desc[kIOPSPowerSourceStateKey] as? String {
                    if state == kIOPSBatteryPowerValue {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func startEnergyStatusTimer() {
        energyStatusTimer?.invalidate()
        energyStatusTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkAndSyncEnergyStatus()
        }
        // Run once immediately
        checkAndSyncEnergyStatus()
    }
    
    private func checkAndSyncEnergyStatus() {
        guard let inst = instance else { return }
        let status = getSystemEnergyStatus()
        
        // Only sync if status changed
        if lastEnergyStatus["isOnBattery"] as? Bool != status["isOnBattery"] as? Bool ||
           lastEnergyStatus["isAppActive"] as? Bool != status["isAppActive"] as? Bool ||
           lastEnergyStatus["isLowPowerMode"] as? Bool != status["isLowPowerMode"] as? Bool {
            
            lastEnergyStatus = status
            
            let channel = FlutterMethodChannel(
                name: "com.breakmate.desktop/companion_data",
                binaryMessenger: inst.engine.binaryMessenger
            )
            channel.invokeMethod("syncCompanionSettings", arguments: status)
        }
    }
}
