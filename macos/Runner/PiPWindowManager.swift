// PiPWindowManager.swift
//
// Manages the Picture-in-Picture (PiP) companion window — a small, always-on-top
// floating NSPanel that contains a dedicated Flutter engine running `pipMain`.
//
// The pet roams freely inside the window using the Flame game engine.
// Interaction buttons (Feed, Play, Pet, Wave) are rendered by Flutter on top of
// the Flame canvas and fire FSM events back to the game via EventBus.
//
// Bridge channel: com.breakmate.desktop/bridge
//   - showPipWindow(args)  — creates / shows the PiP window
//   - hidePipWindow        — hides and disposes the PiP window
//
// Data channel:  com.breakmate.desktop/pip_data  (inside PiP engine)
//   - getInitialSettings   — Flutter pulls its initial config on startup
//   - syncPiPSettings      — push live updates (theme, scale, petName)

import Cocoa
import FlutterMacOS

// MARK: - PiPWindowManager

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

    // MARK: - Public API

    /// Show the PiP window, spawning a new Flutter engine if needed.
    /// `args` may contain: x, y, width, height, themeId, petName, scale.
    func showPipWindow(args: [String: Any]?) {
        guard pipInstance == nil && !isSettingUp else {
            if let args = args { syncSettings(args) }
            return
        }
        isSettingUp = true

        // Geometry — default to bottom-right of primary display.
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let w = min(max((args?["width"] as? Double) ?? 280, 200), 600)
        let h = min(max((args?["height"] as? Double) ?? 320, 200), 600)
        let x = (args?["x"] as? Double) ?? (screenFrame.maxX - w - 20)
        let y = (args?["y"] as? Double) ?? (screenFrame.minY + 20)

        let frame = NSRect(x: x, y: y, width: w, height: h)

        let window = PiPPanel(frame: frame)

        // Dedicated Flutter engine running the pipMain entry point.
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

        // Data channel — Flutter pulls initial settings and receives live updates.
        let pendingArgs = args ?? [:]
        let dataChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/pip_data",
            binaryMessenger: engine.binaryMessenger
        )
        dataChannel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "getInitialSettings":
                result(pendingArgs)
            case "syncPiPSettings":
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Setup MethodChannel for behavior engine bridge
        let bridgeChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/bridge",
            binaryMessenger: engine.binaryMessenger
        )
        bridgeChannel.setMethodCallHandler { call, result in
            BehaviorEngineBridge.shared.handleMethodCall(call, result: result)
        }

        isSettingUp = false

        window.alphaValue = 0.0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            window.animator().alphaValue = 1.0
        }
    }

    /// Hide and dispose the PiP window.
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

    /// Push live settings update to the Flutter PiP engine.
    func syncSettings(_ args: [String: Any]) {
        guard let inst = pipInstance else { return }
        let dataChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/pip_data",
            binaryMessenger: inst.engine.binaryMessenger
        )
        dataChannel.invokeMethod("syncPiPSettings", arguments: args)
    }
}

// MARK: - PiPPanel

/// A compact, frameless, always-on-top floating panel.
/// - Transparent background so the Flame canvas is the only visual surface.
/// - Draggable by its background (isMovableByWindowBackground).
/// - Resizable within [200, 600] logical px range.
/// - Has a thin rounded-rect border drawn by the Flutter widget.
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

        backgroundColor       = NSColor(white: 0.08, alpha: 0.82)
        isOpaque              = false
        hasShadow             = true
        level                 = .floating
        isMovableByWindowBackground = true
        collectionBehavior    = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // Size constraints
        minSize = NSSize(width: 200, height: 200)
        maxSize = NSSize(width: 600, height: 600)

        // Corner radius via the backing layer
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius   = 14
        contentView?.layer?.masksToBounds  = true

        delegate = self
    }

    // Enforce min/max during live resize
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let clampedW = max(200, min(600, frameSize.width))
        let clampedH = max(200, min(600, frameSize.height))
        return NSSize(width: clampedW, height: clampedH)
    }

    // Close button = hide (not terminate)
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        PiPWindowManager.shared.hidePipWindow()
        return false
    }
}
