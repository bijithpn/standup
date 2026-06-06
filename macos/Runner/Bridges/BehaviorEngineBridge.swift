// BehaviorEngineBridge.swift
//
// Implements the macOS native side for the 7 new Pet Behavior Engine PAL methods:
//   1.  enumerateDisplays       — returns all connected displays
//   2.  registerDisplayChangeCallback — fires via EventChannel when screens change
//   3.  getCursorPosition       — returns current cursor in screen-top-left coords
//   4.  getVisibleWindows       — returns visible non-minimized app windows via CGWindowList
//   5.  showConstraintWindow    — creates/shows the constraint NSWindow
//   6.  hideConstraintWindow    — hides the constraint NSWindow
//   7.  registerConstraintWindowBoundsCallback — fires via EventChannel on move/resize
//
// Channel names (must match Dart MacOSBridge / WindowsBridge):
//   MethodChannel:  com.breakmate.desktop/bridge
//   EventChannel:   com.breakmate.desktop/displayChange
//   EventChannel:   com.breakmate.desktop/constraintWindowBounds
//
// Registration: call BehaviorEngineBridge.shared.setup(binaryMessenger:) from
// MainFlutterWindow.configureBridge() after the main bridge is configured.

import Cocoa
import FlutterMacOS

// MARK: - BehaviorEngineBridge

final class BehaviorEngineBridge: NSObject, FlutterPlugin {
    static let shared = BehaviorEngineBridge()

    private var displayChangeSink: FlutterEventSink?
    private var constraintBoundsSink: FlutterEventSink?

    private var constraintWindow: ConstraintBorderWindow?
    private var constraintWindowDelegate: ConstraintWindowDelegate?

    private override init() { super.init() }

    // MARK: - Setup

    static func register(with registrar: FlutterPluginRegistrar) {
        let bridge = BehaviorEngineBridge.shared
        
        let methodChannel = FlutterMethodChannel(
            name: "com.breakmate.desktop/bridge",
            binaryMessenger: registrar.messenger
        )
        registrar.addMethodCallDelegate(bridge, channel: methodChannel)
        
        // EventChannel — display changes (NSApplicationDidChangeScreenParametersNotification)
        let displayEventChannel = FlutterEventChannel(
            name: "com.breakmate.desktop/displayChange",
            binaryMessenger: registrar.messenger
        )
        displayEventChannel.setStreamHandler(DisplayChangeStreamHandler.shared)

        // EventChannel — constraint window bounds changes
        let constraintEventChannel = FlutterEventChannel(
            name: "com.breakmate.desktop/constraintWindowBounds",
            binaryMessenger: registrar.messenger
        )
        constraintEventChannel.setStreamHandler(ConstraintBoundsStreamHandler.shared)
    }

    func setup(binaryMessenger: FlutterBinaryMessenger) {
        // EventChannel — display changes (NSApplicationDidChangeScreenParametersNotification)
        let displayEventChannel = FlutterEventChannel(
            name: "com.breakmate.desktop/displayChange",
            binaryMessenger: binaryMessenger
        )
        displayEventChannel.setStreamHandler(DisplayChangeStreamHandler.shared)

        // EventChannel — constraint window bounds changes
        let constraintEventChannel = FlutterEventChannel(
            name: "com.breakmate.desktop/constraintWindowBounds",
            binaryMessenger: binaryMessenger
        )
        constraintEventChannel.setStreamHandler(ConstraintBoundsStreamHandler.shared)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "enumerateDisplays":
            handleEnumerateDisplays(result: result)
        case "getCursorPosition":
            handleGetCursorPosition(result: result)
        case "getVisibleWindows":
            handleGetVisibleWindows(result: result)
        case "showConstraintWindow":
            handleShowConstraintWindow(args: args, result: result)
        case "hideConstraintWindow":
            handleHideConstraintWindow(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method Handlers

    /// Returns the list of connected displays in the format expected by `NativeDisplayManager`.
    func handleEnumerateDisplays(result: FlutterResult) {
        result(Self.enumerateDisplays())
    }

    /// Returns the current cursor position in screen-**top**-left coordinates
    /// (Flame / Flutter convention), converted from macOS screen-bottom-left.
    func handleGetCursorPosition(result: FlutterResult) {
        let mouseLocation = NSEvent.mouseLocation
        // Convert from macOS bottom-left origin to top-left origin using the
        // primary screen height.  Matches Flutter's coordinate space.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let flippedY = primaryHeight - mouseLocation.y
        result(["x": mouseLocation.x, "y": flippedY])
    }

    /// Returns all visible, non-minimized top-level application windows via CGWindowList.
    func handleGetVisibleWindows(result: FlutterResult) {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            result([])
            return
        }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var windows: [[String: Any]] = []

        for info in windowList {
            guard
                let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                let boundsDict = info[kCGWindowBounds as String] as? [String: Double],
                let x = boundsDict["X"],
                let y = boundsDict["Y"],
                let w = boundsDict["Width"],
                let h = boundsDict["Height"],
                w > 0, h > 0
            else { continue }

            let windowId  = info[kCGWindowNumber as String] as? Int ?? 0
            let ownerName = info[kCGWindowOwnerName as String] as? String
            let title     = info[kCGWindowName as String] as? String
            let alpha     = info[kCGWindowAlpha as String] as? Double ?? 1.0

            // CGWindowList uses screen-bottom-left origin; convert to screen-top-left.
            let flippedY = primaryHeight - y - h

            windows.append([
                "windowId":    windowId,
                "appBundleId": ownerName ?? "",
                "windowTitle": title ?? "",
                "x":           x,
                "y":           flippedY,
                "width":       w,
                "height":      h,
                "isMinimized": false,  // Layer 0 windows on screen are not minimized
                "isVisible":   alpha > 0
            ])
        }

        result(windows)
    }

    /// Shows the constraint border window at the specified position and size.
    func handleShowConstraintWindow(args: [String: Any]?, result: FlutterResult) {
        let x = (args?["x"] as? Double) ?? 100
        let y = (args?["y"] as? Double) ?? 100
        let w = (args?["width"] as? Double) ?? 300
        let h = (args?["height"] as? Double) ?? 300

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Convert from Flame top-left to macOS bottom-left origin.
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            let macOSY = primaryHeight - y - h

            let frame = NSRect(x: x, y: macOSY, width: w, height: h)

            if let existing = self.constraintWindow {
                existing.setFrame(frame, display: true, animate: false)
                existing.orderFrontRegardless()
            } else {
                let win = ConstraintBorderWindow(frame: frame)
                let delegate = ConstraintWindowDelegate()
                delegate.onBoundsChanged = { [weak self] bounds in
                    self?.didUpdateConstraintBounds(bounds)
                }
                win.delegate = delegate
                self.constraintWindow = win
                self.constraintWindowDelegate = delegate
                win.orderFrontRegardless()
            }

            result(nil)
        }
    }

    /// Hides and removes the constraint window.
    func handleHideConstraintWindow(result: FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.constraintWindow?.orderOut(nil)
            self?.constraintWindow?.delegate = nil
            self?.constraintWindow = nil
            self?.constraintWindowDelegate = nil
            result(nil)
        }
    }

    // MARK: - Private helpers

    static func enumerateDisplays() -> [[String: Any]] {
        var displays: [[String: Any]] = []
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            var displayId = "Display_\(index)"
            if #available(macOS 10.15, *) {
                displayId = screen.localizedName
            }
            displays.append([
                "id":        displayId,
                "x":         frame.origin.x,
                "y":         frame.origin.y,
                "width":     frame.width,
                "height":    frame.height,
                "dpiScale":  screen.backingScaleFactor,
                "isPrimary": index == 0
            ])
        }
        return displays
    }

    private func didUpdateConstraintBounds(_ bounds: NSRect) {
        // Convert macOS bottom-left origin → Flame top-left origin.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let flippedY = primaryHeight - bounds.origin.y - bounds.height
        let payload: [String: Any] = [
            "x":      bounds.origin.x,
            "y":      flippedY,
            "width":  bounds.width,
            "height": bounds.height
        ]
        ConstraintBoundsStreamHandler.shared.send(payload)
    }
}

// MARK: - DisplayChangeStreamHandler

/// FlutterStreamHandler that forwards NSApplicationDidChangeScreenParametersNotification
/// to the `com.breakmate.desktop/displayChange` EventChannel.
final class DisplayChangeStreamHandler: NSObject, FlutterStreamHandler {
    static let shared = DisplayChangeStreamHandler()
    private var eventSink: FlutterEventSink?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
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
        let displays = BehaviorEngineBridge.enumerateDisplays()
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(displays)
        }
    }
}

// MARK: - ConstraintBoundsStreamHandler

/// FlutterStreamHandler for the `com.breakmate.desktop/constraintWindowBounds` EventChannel.
final class ConstraintBoundsStreamHandler: NSObject, FlutterStreamHandler {
    static let shared = ConstraintBoundsStreamHandler()
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func send(_ payload: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }
}

// MARK: - ConstraintBorderWindow

/// A small, resizable, always-on-top NSWindow that defines the spatial boundary
/// for Constrained Mode.  Transparent interior, dashed-border appearance.
final class ConstraintBorderWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.titled, .resizable, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.title = "Constraint Zone"
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.minSize = NSSize(width: 200, height: 200)
        self.maxSize = NSSize(width: 800, height: 800)

        // Install a dashed-border content view
        let borderView = ConstraintBorderView(frame: NSRect(origin: .zero, size: frame.size))
        self.contentView = borderView
    }
}

// MARK: - ConstraintBorderView

/// Draws a dashed border to visually indicate the constraint zone boundary.
final class ConstraintBorderView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let path = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
        path.lineWidth = 2.0
        let dashPattern: [CGFloat] = [8, 4]
        path.setLineDash(dashPattern, count: 2, phase: 0)
        NSColor.systemBlue.withAlphaComponent(0.8).setStroke()
        path.stroke()
    }
}

// MARK: - ConstraintWindowDelegate

/// NSWindowDelegate that fires `onBoundsChanged` whenever the window is moved or resized.
final class ConstraintWindowDelegate: NSObject, NSWindowDelegate {
    var onBoundsChanged: ((NSRect) -> Void)?

    func windowDidMove(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        onBoundsChanged?(win.frame)
    }

    func windowDidResize(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        onBoundsChanged?(win.frame)
    }
}
