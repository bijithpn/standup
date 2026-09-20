import Cocoa
import FlutterMacOS

/// A borderless, non-activating panel that floats above other apps.
///
/// `canBecomeKey` stays true, unlike the fullscreen companion panel: this one
/// is draggable and clickable, and a panel that can never become key cannot
/// receive the mouse events the pet reacts to.
final class PiPFlutterPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return false }
}

/// Hosts the companion picture-in-picture window as a Flutter surface.
///
/// This replaces the `WKWebView` build of the same window. The pet is now drawn
/// by `PiPOverlayWindow` in Dart, through the same isolate-backed renderer the
/// rest of the app uses, which removes a whole WebKit process and its WebGL
/// context from a window that is open all day. It is deliberately modelled on
/// `CompanionWindowManager` so both secondary engines are set up the same way.
final class PiPFlutterWindowManager: NSObject {
    static let shared = PiPFlutterWindowManager()

    private struct Instance {
        let window: PiPFlutterPanel
        let engine: FlutterEngine
        let controller: FlutterViewController
        let channel: FlutterMethodChannel
    }

    private var instance: Instance?
    private var isSettingUp = false

    /// Flutter pulls these once its handler is registered, so a settings push
    /// that lands before the engine is ready is not lost.
    private var pendingInitialArgs: [String: Any]?

    private override init() { super.init() }

    var isVisible: Bool {
        return instance?.window.isVisible ?? false
    }

    // MARK: - Lifecycle

    func showPipWindow(args: [String: Any]?) {
        if let existing = instance {
            pendingInitialArgs = args
            if let args = args {
                existing.channel.invokeMethod("syncPiPSettings", arguments: args)
                applyWindowSettings(args: args, window: existing.window)
            }
            existing.window.setIsVisible(true)
            existing.window.orderFrontRegardless()
            return
        }

        guard !isSettingUp else { return }
        isSettingUp = true

        // Clear out any panel a crashed engine left behind.
        for window in NSApp.windows {
            if let stale = window as? PiPFlutterPanel {
                stale.orderOut(nil)
                stale.contentViewController = nil
                stale.contentView = nil
            }
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let width = min(max((args?["width"] as? Double) ?? 280, 160), 640)
        let height = min(max((args?["height"] as? Double) ?? 320, 180), 720)
        let x = (args?["x"] as? Double) ?? Double(screenFrame.maxX - CGFloat(width) - 20)
        let y = (args?["y"] as? Double) ?? Double(screenFrame.minY + 20)

        let frame = NSRect(x: x, y: y, width: width, height: height)

        let window = PiPFlutterPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]

        let engine = FlutterEngine(
            name: "PiPEngine",
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

        window.contentView = controller.view

        pendingInitialArgs = args

        let channel = FlutterMethodChannel(
            name: "com.breakmate.desktop/pip_data",
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "getInitialSettings" {
                result(self?.pendingInitialArgs ?? [:])
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // The pet asks for the cursor over this channel, so it has to answer on
        // the PiP engine too. Everything the PiP does not own itself is handed
        // to the shared bridge.
        let bridgeChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/bridge",
            binaryMessenger: engine.binaryMessenger
        )
        bridgeChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "hidePipWindow":
                // Answer first, then tear down on the next turn of the run
                // loop: shutting the engine down while it is still delivering
                // this very call would pull the floor out from under it.
                result(nil)
                DispatchQueue.main.async { self?.hidePipWindow() }
            default:
                BehaviorEngineBridge.shared.handle(call, result: result)
            }
        }

        instance = Instance(
            window: window,
            engine: engine,
            controller: controller,
            channel: channel
        )
        isSettingUp = false

        if let args = args {
            applyWindowSettings(args: args, window: window)
            channel.invokeMethod("syncPiPSettings", arguments: args)
        }

        // Fade in once the engine has drawn its first transparent frame,
        // otherwise the panel flashes opaque black.
        window.alphaValue = 0.0
        window.orderFrontRegardless()
        let targetAlpha = CGFloat(max(0.1, min(1.0, (args?["pipOpacity"] as? Double) ?? 1.0)))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = targetAlpha
            }
        }
    }

    func hidePipWindow() {
        guard let current = instance else { return }
        instance = nil
        pendingInitialArgs = nil

        current.channel.setMethodCallHandler(nil)
        FlutterMethodChannel(
            name: "com.breakmate.desktop/bridge",
            binaryMessenger: current.engine.binaryMessenger
        ).setMethodCallHandler(nil)
        IpcBridgeManager.shared.unregister(engine: current.engine)

        current.window.orderOut(nil)
        current.window.contentViewController = nil
        current.window.contentView = nil
        current.engine.shutDownEngine()
    }

    // MARK: - Live updates

    func syncSettings(_ args: [String: Any]) {
        guard let current = instance else { return }
        pendingInitialArgs = args
        applyWindowSettings(args: args, window: current.window)
        current.channel.invokeMethod("syncPiPSettings", arguments: args)
    }

    func updateTheme(themeId: String, extra: [String: Any]?) {
        guard let current = instance else { return }
        var payload: [String: Any] = extra ?? [:]
        payload["themeId"] = themeId
        current.channel.invokeMethod("updateCompanionTheme", arguments: payload)
    }

    func updatePetName(_ petName: String) {
        guard let current = instance else { return }
        current.channel.invokeMethod(
            "updateCompanionName",
            arguments: ["petName": petName]
        )
    }

    /// Applies the settings that belong to the panel rather than to Flutter.
    private func applyWindowSettings(args: [String: Any], window: NSWindow) {
        if let opacity = args["pipOpacity"] as? Double, window.alphaValue > 0 {
            window.alphaValue = CGFloat(max(0.1, min(1.0, opacity)))
        }
        if let draggableClickable = args["pipDraggableClickable"] as? Bool {
            window.ignoresMouseEvents = !draggableClickable
        }
    }
}
