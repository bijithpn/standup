import Cocoa
import FlutterMacOS

class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool {
        return false // Floating companion never steals keyboard focus
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

class CompanionViewController: FlutterViewController {
    override func mouseDown(with event: NSEvent) {
        // Allow the user to drag the floating window from anywhere within the Flutter view
        self.view.window?.performDrag(with: event)
        super.mouseDown(with: event)
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
            // Already active, just update parameters
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
        window.level = .floating // Float persistently above regular windows
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        
        // CRITICAL: Enables standard native click-to-drag anywhere on non-transparent elements of the pet!
        window.isMovableByWindowBackground = true
        
        // Spawn a fresh, dedicated engine for the Flame rendering thread
        let engine = FlutterEngine(name: "CompanionEngine", project: nil, allowHeadlessExecution: true)
        engine.run(withEntrypoint: "companionMain")
        
        // Register standard plugins (allows MethodChannels, shared preferences, etc.)
        RegisterGeneratedPlugins(registry: engine)
        
        let controller = CompanionViewController(engine: engine, nibName: nil, bundle: nil)
        controller.backgroundColor = .clear
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Make the Flutter content stretch fully
        controller.view.autoresizingMask = [.width, .height]
        controller.view.frame = NSRect(origin: .zero, size: frame.size)
        
        window.contentView = controller.view
        
        instance = CompanionInstance(window: window, engine: engine, controller: controller)
        
        // Parse arguments for initial state mapping
        if let args = args {
            updateCompanionParams(args: args)
        }
        
        window.makeKeyAndOrderFront(nil)
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
}
