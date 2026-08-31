import Cocoa
import FlutterMacOS

/// Detects when another application is occupying the entire main display —
/// the common shape of a Keynote/PowerPoint slideshow, a fullscreen video
/// call window, or a shared-screen presentation — so BreakMate can defer
/// break overlays rather than interrupt a presentation in progress.
///
/// This is a heuristic, not true "is my screen being shared" detection:
/// there is no public API to ask another app whether it is currently
/// sharing its screen over Zoom/Meet/Teams. Covering a full display with a
/// borderless/fullscreen window is the closest reliable, permission-free
/// signal available via `CGWindowListCopyWindowInfo` (window bounds/layer
/// are available without Screen Recording permission; only window titles
/// require it, and this bridge never reads titles).
class PresentationDetectionBridge: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var pollTimer: Timer?
    private var lastIsPresenting: Bool?

    init(registrar: FlutterPluginRegistrar) {
        super.init()
        let channel = FlutterEventChannel(name: "com.breakmate/presentation_detection", binaryMessenger: registrar.messenger)
        channel.setStreamHandler(self)
    }

    deinit {
        pollTimer?.invalidate()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkFullscreenState()
        }
        checkFullscreenState()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        pollTimer?.invalidate()
        pollTimer = nil
        self.eventSink = nil
        return nil
    }

    private func checkFullscreenState() {
        let isPresenting = Self.isAnyWindowCoveringMainDisplay()
        guard isPresenting != lastIsPresenting else { return }
        lastIsPresenting = isPresenting
        eventSink?(["isPresenting": isPresenting])
    }

    /// Returns true if any on-screen, normal-layer window (belonging to any
    /// app, not just BreakMate) covers at least 95% of the main display's
    /// area — the shape of a fullscreen slideshow or presentation window.
    static func isAnyWindowCoveringMainDisplay() -> Bool {
        guard let screenFrame = NSScreen.main?.frame else { return false }
        let screenArea = screenFrame.width * screenFrame.height
        guard screenArea > 0 else { return false }

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: AnyObject]] else {
            return false
        }

        let ownPid = ProcessInfo.processInfo.processIdentifier

        for window in windowList {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let ownerPid = window[kCGWindowOwnerPID as String] as? Int32, ownerPid != ownPid else { continue }
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            guard let width = boundsDict["Width"], let height = boundsDict["Height"] else { continue }

            let windowArea = width * height
            if windowArea >= screenArea * 0.95 {
                return true
            }
        }
        return false
    }
}
