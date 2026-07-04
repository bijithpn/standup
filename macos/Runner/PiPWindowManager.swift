
import Cocoa
import FlutterMacOS

final class PiPWindowManager: NSObject {
    static let shared = PiPWindowManager()

    private var pipInstance: PiPInstance?
    private var isSettingUp = false

    struct PiPInstance {
        let window: PiPPanel
        let engine: FlutterEngine
        let controller: FlutterViewController
    }

    private override init() { super.init() }

    func showPipWindow(args: [String: Any]?) {
        guard pipInstance == nil && !isSettingUp else {
            if let args = args { syncSettings(args) }
            return
        }
        isSettingUp = true

        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let w = min(max((args?["width"] as? Double) ?? 280, 200), 600)
        let h = min(max((args?["height"] as? Double) ?? 320, 200), 600)
        let x = (args?["x"] as? Double) ?? (screenFrame.maxX - w - 20)
        let y = (args?["y"] as? Double) ?? (screenFrame.minY + 20)

        let frame = NSRect(x: x, y: y, width: w, height: h)

        let window = PiPPanel(frame: frame)

        let engine = FlutterEngine(
            name: "PiPEngine-\(UUID().uuidString)",
            project: nil,
            allowHeadlessExecution: true
        )
        engine.run(withEntrypoint: "pipMain")
        RegisterSecondaryPlugins(registry: engine)
        IpcBridgeManager.shared.register(engine: engine)

        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        controller.backgroundColor = .clear
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        controller.view.autoresizingMask = [.width, .height]
        controller.view.frame = NSRect(origin: .zero, size: frame.size)

        window.contentViewController = controller
        window.contentView = controller.view

        pipInstance = PiPInstance(window: window, engine: engine, controller: controller)

        let pendingArgs = args ?? [:]
        let dataChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/pip_data",
            binaryMessenger: engine.binaryMessenger
        )
        dataChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "getInitialSettings":
                result(pendingArgs)
            case "syncPiPSettings":
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let bridgeChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/bridge",
            binaryMessenger: engine.binaryMessenger
        )
        bridgeChannel.setMethodCallHandler { call, result in
            if call.method == "hidePipWindow" {
                PiPWindowManager.shared.hidePipWindow()
                result(nil)
            } else {
                BehaviorEngineBridge.shared.handle(call, result: result)
            }
        }

        isSettingUp = false

        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                window.animator().alphaValue = 1.0
            }
        }
    }

    func hidePipWindow() {
        isSettingUp = false
        guard let inst = pipInstance else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            inst.window.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            inst.window.orderOut(nil)
            inst.window.contentViewController = nil
            inst.window.contentView = nil

            let dataChannel = FlutterMethodChannel(
                name: "com.breakmate.desktop/pip_data",
                binaryMessenger: inst.engine.binaryMessenger
            )
            dataChannel.setMethodCallHandler(nil)

            IpcBridgeManager.shared.unregister(engine: inst.engine)
            inst.engine.shutDownEngine()
            self?.pipInstance = nil
        })
    }

    func syncSettings(_ args: [String: Any]) {
        guard let inst = pipInstance else { return }
        let dataChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/pip_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        dataChannel.invokeMethod("syncPiPSettings", arguments: args)
    }
}

final class PiPPanel: NSPanel, NSWindowDelegate {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [
                .borderless,
                .resizable,
                .nonactivatingPanel,
                .utilityWindow
            ],
            backing: .buffered,
            defer: false
        )

        backgroundColor       = NSColor.clear
        isOpaque              = false
        hasShadow             = true
        level                 = .floating
        hidesOnDeactivate     = false
        isMovableByWindowBackground = true
        collectionBehavior    = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        minSize = NSSize(width: 200, height: 200)
        maxSize = NSSize(width: 600, height: 600)

        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius   = 14
        contentView?.layer?.masksToBounds  = true

        delegate = self
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let clampedW = max(200, min(600, frameSize.width))
        let clampedH = max(200, min(600, frameSize.height))
        return NSSize(width: clampedW, height: clampedH)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        PiPWindowManager.shared.hidePipWindow()
        return false
    }
}
