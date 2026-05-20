import Cocoa
import FlutterMacOS

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
        guard instance == nil else {
            if let args = args {
                updateCompanionParams(args: args)
            }
            return
        }
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Companion container window size
        let width: CGFloat = 350
        let height: CGFloat = 300
        
        // Position at bottom-right corner with margins
        let x = screenFrame.maxX - width - 40
        let y = screenFrame.minY + 40
        let frame = NSRect(x: x, y: y, width: width, height: height)
        
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
        
        // CRITICAL: Do NOT ignore mouse events — we need them for drag & cat interaction
        window.ignoresMouseEvents = false
        
        // Spawn a fresh, dedicated Flutter engine with its own Dart isolate.
        let engine = FlutterEngine(
            name: "CompanionEngine",
            project: nil,
            allowHeadlessExecution: true
        )
        engine.run(withEntrypoint: "companionMain")
        RegisterGeneratedPlugins(registry: engine)
        
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
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        controller.backgroundColor = .clear
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        controller.view.autoresizingMask = [.width, .height]
        controller.view.frame = frame
        
        window.contentView = controller.view
        
        instance = CompanionInstance(window: window, engine: engine, controller: controller)
        
        // Setup MethodChannel for native drag tracking and overlay synchronization
        let channel = FlutterMethodChannel(
            name: "com.breakmate.macos/companion_data",
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            if call.method == "syncCompanionSettings" {
                if let args = call.arguments as? [String: Any],
                   let positionDelta = args["positionDelta"] as? [String: Any] {
                    let dx = (positionDelta["dx"] as? NSNumber)?.doubleValue ?? 0.0
                    let dy = (positionDelta["dy"] as? NSNumber)?.doubleValue ?? 0.0
                    DispatchQueue.main.async {
                        self.moveCompanionWindow(dx: dx, dy: dy)
                    }
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        if let args = args {
            updateCompanionParams(args: args)
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func moveCompanionWindow(dx: Double, dy: Double) {
        guard let inst = instance else { return }
        var frame = inst.window.frame
        frame.origin.x += CGFloat(dx)
        frame.origin.y -= CGFloat(dy)
        inst.window.setFrame(frame, display: true)
    }
    
    /// Dynamic companion updater. Passes changes down to the companion Flutter engine.
    private func updateCompanionParams(args: [String: Any]) {
        guard let instance = instance else { return }
        
        if let clickThrough = args["clickThrough"] as? Bool {
            instance.window.ignoresMouseEvents = clickThrough
        }
        
        let channel = FlutterMethodChannel(
            name: "com.breakmate.macos/companion_data",
            binaryMessenger: instance.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: args)
    }
    
    /// Hides and terminates the companion overlay processes cleanly.
    func hideCompanion() {
        guard let inst = instance else { return }
        
        inst.window.orderOut(nil)
        inst.engine.shutDownEngine()
        instance = nil
    }
    
    /// Dynamic click-through modifier.
    func setClickThrough(_ enabled: Bool) {
        instance?.window.ignoresMouseEvents = enabled
    }
    
    /// Swaps themes dynamically at runtime.
    func updateTheme(_ themeId: String) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.macos/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["themeId": themeId])
    }
    
    /// Modifies companion scaling factor and adjusts container bounds accordingly.
    func updateScale(_ scale: Double) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.macos/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["scale": scale])
    }

    /// Triggers a dynamic behavioral animation state on the secondary Flame engine.
    func triggerState(_ state: String) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.macos/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["state": state])
    }

    /// Sets whether wandering AI is enabled on the secondary Flame engine.
    func setWanderingEnabled(_ enabled: Bool) {
        guard let inst = instance else { return }
        let channel = FlutterMethodChannel(
            name: "com.breakmate.macos/companion_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        channel.invokeMethod("syncCompanionSettings", arguments: ["wanderingEnabled": enabled])
    }
    
    /// Updates window level for always-on-top behavior
    func setAlwaysOnTop(_ enabled: Bool) {
        instance?.window.level = enabled ? .floating : .normal
    }
    
    /// Moves the companion window to a specific position
    func setPosition(x: Double, y: Double) {
        guard let inst = instance else { return }
        var frame = inst.window.frame
        frame.origin.x = x
        frame.origin.y = y
        inst.window.setFrame(frame, display: true)
    }
    
    /// Resizes the companion window
    func setSize(width: Double, height: Double) {
        guard let inst = instance else { return }
        var frame = inst.window.frame
        frame.size.width = width
        frame.size.height = height
        inst.window.setFrame(frame, display: true)
    }
}
