
import Cocoa
import FlutterMacOS
import WebKit

final class PiPWebView: WKWebView {
    var isDraggable: Bool = true
    var onBackgroundToggle: (() -> Void)?
    var onShowContextMenu: ((NSEvent) -> Void)?
    private var dragStartScreenPoint: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onBackgroundToggle?()
            return
        }

        if isDraggable, let window = self.window {
            dragStartScreenPoint = NSEvent.mouseLocation
            dragStartWindowOrigin = window.frame.origin
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if isDraggable, let window = self.window {
            let current = NSEvent.mouseLocation
            let deltaX = current.x - dragStartScreenPoint.x
            let deltaY = current.y - dragStartScreenPoint.y
            window.setFrameOrigin(NSPoint(x: dragStartWindowOrigin.x + deltaX, y: dragStartWindowOrigin.y + deltaY))
            return
        }
        super.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        if let onShowContextMenu = onShowContextMenu {
            onShowContextMenu(event)
            return
        }
        super.rightMouseDown(with: event)
    }
}

final class PiPDragHandleView: NSView {
    var isDraggable: Bool = true
    private var dragStartScreenPoint: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero
    private var isHovered: Bool = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isDraggable {
            addCursorRect(bounds, cursor: .openHand)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if isDraggable, let window = self.window {
            NSCursor.closedHand.push()
            dragStartScreenPoint = NSEvent.mouseLocation
            dragStartWindowOrigin = window.frame.origin
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.pop()
        super.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if isDraggable, let window = self.window {
            let current = NSEvent.mouseLocation
            let deltaX = current.x - dragStartScreenPoint.x
            let deltaY = current.y - dragStartScreenPoint.y
            window.setFrameOrigin(NSPoint(x: dragStartWindowOrigin.x + deltaX, y: dragStartWindowOrigin.y + deltaY))
            return
        }
        super.mouseDragged(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw 2 rows of 4 dots (8 dots total: •••• / ••••)
        let cols = 4
        let rows = 2
        let dotRadius: CGFloat = 1.75
        let spacingX: CGFloat = 6.5
        let spacingY: CGFloat = 5.0

        let gridW = CGFloat(cols - 1) * spacingX + (dotRadius * 2)
        let gridH = CGFloat(rows - 1) * spacingY + (dotRadius * 2)

        let startX = (bounds.width - gridW) / 2.0 + dotRadius
        let startY = (bounds.height - gridH) / 2.0 + dotRadius

        let alpha: CGFloat = isHovered ? 0.85 : 0.42
        let dotColor = NSColor(white: 0.88, alpha: alpha).cgColor
        let shadowColor = NSColor(white: 0.0, alpha: isHovered ? 0.45 : 0.25).cgColor

        for r in 0..<rows {
            for c in 0..<cols {
                let cx = startX + CGFloat(c) * spacingX
                let cy = startY + CGFloat(r) * spacingY

                // Subtle shadow for legibility over bright or complex backgrounds
                ctx.setFillColor(shadowColor)
                ctx.fillEllipse(in: CGRect(x: cx - dotRadius, y: cy - dotRadius - 0.75, width: dotRadius * 2, height: dotRadius * 2))

                // Dots
                ctx.setFillColor(dotColor)
                ctx.fillEllipse(in: CGRect(x: cx - dotRadius, y: cy - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            }
        }
    }
}

final class PiPWindowManager: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = PiPWindowManager()

    private var pipWindow: PiPPanel?
    private var webView: PiPWebView?
    private var dragHandleView: PiPDragHandleView?
    private var containerView: NSView?
    private var visualEffectView: NSVisualEffectView?
    private var currentUrlStr: String?
    private var currentBackgroundStyle: String = "transparent"

    private var cursorTrackingTimer: Timer?
    private var isFollowMouseEnabled: Bool = true
    private var currentYaw: Double = 0.0
    private var currentPitch: Double = 0.0

    private override init() { super.init() }

    func showPipWindow(args: [String: Any]?) {
        let avatarUrlStr = (args?["avatarUrl"] as? String) ?? "http://127.0.0.1:5173/?companion=1#/companion"
        NSLog("[PiPWindowManager] showPipWindow called with avatarUrl: %@", avatarUrlStr)

        // If window already exists, sync settings or reload if needed
        if let window = pipWindow, webView != nil {
            syncSettings(args ?? [:])
            window.alphaValue = 1.0
            window.setIsVisible(true)
            window.orderFrontRegardless()
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let w = min(max((args?["width"] as? Double) ?? 280, 200), 600)
        let h = min(max((args?["height"] as? Double) ?? 320, 200), 600)
        let x = (args?["x"] as? Double) ?? (screenFrame.maxX - w - 20)
        let y = (args?["y"] as? Double) ?? (screenFrame.minY + 20)

        let frame = NSRect(x: x, y: y, width: w, height: h)
        NSLog("[PiPWindowManager] Creating PiPPanel at frame: (%f, %f, %f, %f)", x, y, w, h)
        let window = PiPPanel(frame: frame)

        let webConfiguration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        let logScript = WKUserScript(
            source: """
            window.addEventListener('error', function(e) {
                window.webkit.messageHandlers.logging.postMessage('JS_ERROR: ' + e.message + ' at ' + (e.filename || '') + ':' + (e.lineno || ''));
            });
            const origError = console.error;
            console.error = function() {
                origError.apply(console, arguments);
                const args = Array.from(arguments).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
                window.webkit.messageHandlers.logging.postMessage('CONSOLE_ERROR: ' + args);
            };
            const origLog = console.log;
            console.log = function() {
                origLog.apply(console, arguments);
                const args = Array.from(arguments).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
                window.webkit.messageHandlers.logging.postMessage('CONSOLE_LOG: ' + args);
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(logScript)

        // Inject script to clean PiP UI: remove rotate, timeline, orientation controls & enable dragging
        let cleanCompanionScript = WKUserScript(
            source: """
            (function() {
                window.AvatarBridge = {
                    setLookAt: function(x, y) {
                        const yaw = x * 0.42;
                        const pitch = -y * 0.32;
                        window.postMessage({ type: 'SET_POSE', yaw: yaw, pitch: pitch }, '*');
                    },
                    setYaw: function(r) {
                        window.postMessage({ type: 'SET_POSE', yaw: r }, '*');
                    }
                };

                const styleId = 'pip-companion-clean-style';
                function injectCleanStyle() {
                    if (document.getElementById(styleId)) return;
                    const style = document.createElement('style');
                    style.id = styleId;
                    style.textContent = `
                        /* Remove rotate, timeline, camera controls, orientation cube, and sidebars in PiP */
                        .avatar-app__interaction-mode,
                        .avatar-app__animation-toggle,
                        .avatar-orientation-control,
                        .avatar-app__camera-tools,
                        .avatar-app__stage-actions,
                        .avatar-controls,
                        .avatar-app__workspace-toggle,
                        .avatar-app__resources-toggle,
                        .avatar-app__controls-toggle,
                        .avatar-header,
                        .avatar-app__header {
                            display: none !important;
                            visibility: hidden !important;
                            opacity: 0 !important;
                            pointer-events: none !important;
                        }

                        html, body, #root, .avatar-app, .avatar-app__stage, .avatar-app__workspace {
                            background: transparent !important;
                            background-color: transparent !important;
                            overflow: hidden !important;
                            margin: 0 !important;
                            padding: 0 !important;
                            width: 100vw !important;
                            height: 100vh !important;
                            min-height: 100vh !important;
                            user-select: none !important;
                            -webkit-user-select: none !important;
                        }

                        .avatar-app,
                        .avatar-app__workspace,
                        .avatar-app__stage {
                            display: flex !important;
                            flex-direction: column !important;
                            align-items: center !important;
                            justify-content: center !important;
                        }

                        .avatar-app__stage-preview {
                            display: flex !important;
                            align-items: center !important;
                            justify-content: center !important;
                            width: 100% !important;
                            height: 100% !important;
                            max-width: none !important;
                            padding: 0 !important;
                            margin: 0 !important;
                            padding-bottom: 16px !important;
                        }

                        #avatar-camera-frame {
                            display: flex !important;
                            align-items: center !important;
                            justify-content: center !important;
                            background: transparent !important;
                            background-color: transparent !important;
                            box-shadow: none !important;
                            border: none !important;
                            width: 100% !important;
                            height: 100% !important;
                            max-width: none !important;
                            max-height: none !important;
                            aspect-ratio: auto !important;
                        }

                        .interactive-avatar,
                        .interactive-avatar__canvas {
                            display: block !important;
                            width: 100% !important;
                            height: 100% !important;
                            max-width: 100% !important;
                            max-height: 100% !important;
                        }

                        html, body, .avatar-app, .avatar-app__stage, .avatar-app__stage-preview, #avatar-camera-frame, svg, canvas {
                            -webkit-app-region: drag !important;
                            cursor: grab;
                        }

                        html:active, body:active, svg:active, canvas:active {
                            cursor: grabbing;
                        }

                        button, a {
                            -webkit-app-region: no-drag !important;
                        }
                    `;
                    (document.head || document.documentElement).appendChild(style);
                }

                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', injectCleanStyle);
                } else {
                    injectCleanStyle();
                }

                const observer = new MutationObserver(injectCleanStyle);
                observer.observe(document.documentElement, { childList: true, subtree: true });
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(cleanCompanionScript)

        userContentController.add(self, name: "logging")
        webConfiguration.userContentController = userContentController
        webConfiguration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true

        let effect = NSVisualEffectView(frame: container.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.material = .hudWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 20
        effect.layer?.masksToBounds = true
        effect.isHidden = true
        container.addSubview(effect)

        let wv = PiPWebView(frame: container.bounds, configuration: webConfiguration)
        wv.autoresizingMask = [.width, .height]
        wv.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            wv.underPageBackgroundColor = .clear
        }
        if #available(macOS 13.3, *) {
            wv.isInspectable = true
        }
        wv.wantsLayer = true
        wv.layer?.cornerRadius = 20
        wv.layer?.masksToBounds = true
        wv.navigationDelegate = self
        wv.onBackgroundToggle = { [weak self] in
            self?.toggleBackgroundStyle()
        }
        wv.onShowContextMenu = { [weak self] event in
            self?.showContextMenu(at: event)
        }
        container.addSubview(wv)

        let handleWidth: CGFloat = 48
        let handleHeight: CGFloat = 16
        let handleX = (container.bounds.width - handleWidth) / 2.0
        let handleY: CGFloat = 8.0
        let dragHandle = PiPDragHandleView(frame: NSRect(x: handleX, y: handleY, width: handleWidth, height: handleHeight))
        dragHandle.autoresizingMask = [.minYMargin, .minXMargin, .maxXMargin]
        if let draggableClickable = args?["pipDraggableClickable"] as? Bool {
            dragHandle.isDraggable = draggableClickable
        }
        container.addSubview(dragHandle)
        self.dragHandleView = dragHandle

        window.contentView = container
        self.pipWindow = window
        self.webView = wv
        self.containerView = container
        self.visualEffectView = effect

        if let bg = args?["pipBackgroundStyle"] as? String {
            applyBackgroundStyle(bg)
        } else {
            applyBackgroundStyle("transparent")
        }

        if let opacity = args?["pipOpacity"] as? Double {
            window.alphaValue = CGFloat(max(0.1, min(1.0, opacity)))
        }

        if let draggableClickable = args?["pipDraggableClickable"] as? Bool {
            window.ignoresMouseEvents = !draggableClickable
            wv.isDraggable = draggableClickable
            dragHandle.isDraggable = draggableClickable
        }

        if let followMouse = args?["followMouse"] as? Bool {
            self.isFollowMouseEnabled = followMouse
        }
        startCursorTracking()

        currentUrlStr = avatarUrlStr
        if let url = URL(string: avatarUrlStr) {
            NSLog("[PiPWindowManager] Loading URL: %@", url.absoluteString)
            wv.load(URLRequest(url: url))
        }

        window.setIsVisible(true)
        window.orderFrontRegardless()
    }

    func hidePipWindow() {
        stopCursorTracking()
        guard let window = pipWindow, let wv = webView else { return }
        wv.stopLoading()
        window.orderOut(nil)
        window.contentView = nil
        self.pipWindow = nil
        self.webView = nil
        self.dragHandleView = nil
        self.containerView = nil
        self.visualEffectView = nil
        self.currentUrlStr = nil
    }

    private func startCursorTracking() {
        cursorTrackingTimer?.invalidate()
        cursorTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            self?.updateHeadTracking()
        }
    }

    private func stopCursorTracking() {
        cursorTrackingTimer?.invalidate()
        cursorTrackingTimer = nil
    }

    private func updateHeadTracking() {
        guard isFollowMouseEnabled, let window = pipWindow, window.isVisible, let wv = webView else { return }
        let mouseLoc = NSEvent.mouseLocation
        let frame = window.frame
        let centerX = frame.midX
        let centerY = frame.midY

        let dx = mouseLoc.x - centerX
        let dy = mouseLoc.y - centerY // In Cocoa, higher Y is higher on screen

        let normX = max(-1.0, min(1.0, dx / 400.0))
        let normY = max(-1.0, min(1.0, dy / 400.0))

        let targetYaw = normX * 0.42
        let targetPitch = -normY * 0.32

        // Smooth lerp (0.25)
        let nextYaw = currentYaw + (targetYaw - currentYaw) * 0.25
        let nextPitch = currentPitch + (targetPitch - currentPitch) * 0.25

        if abs(nextYaw - currentYaw) > 0.003 || abs(nextPitch - currentPitch) > 0.003 {
            currentYaw = nextYaw
            currentPitch = nextPitch
            let script = "window.postMessage({ type: 'SET_POSE', yaw: \(nextYaw), pitch: \(nextPitch) }, '*');"
            wv.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    func syncSettings(_ args: [String: Any]) {
        guard let window = pipWindow, let wv = webView else { return }

        if let backgroundStyle = args["pipBackgroundStyle"] as? String {
            applyBackgroundStyle(backgroundStyle)
        }

        if let opacity = args["pipOpacity"] as? Double {
            window.alphaValue = CGFloat(max(0.1, min(1.0, opacity)))
        }

        if let draggableClickable = args["pipDraggableClickable"] as? Bool {
            window.ignoresMouseEvents = !draggableClickable
            wv.isDraggable = draggableClickable
            dragHandleView?.isDraggable = draggableClickable
        }

        if let followMouse = args["followMouse"] as? Bool {
            isFollowMouseEnabled = followMouse
            if !followMouse {
                wv.evaluateJavaScript("window.postMessage({ type: 'SET_POSE', yaw: 0, pitch: 0 }, '*');", completionHandler: nil)
                currentYaw = 0.0
                currentPitch = 0.0
            }
        }

        if let avatarUrlStr = args["avatarUrl"] as? String,
           !avatarUrlStr.isEmpty,
           avatarUrlStr != currentUrlStr {
            NSLog("[PiPWindowManager] syncSettings: URL changed to %@, reloading WKWebView", avatarUrlStr)
            currentUrlStr = avatarUrlStr
            if let url = URL(string: avatarUrlStr) {
                wv.load(URLRequest(url: url))
            }
            return
        }

        if let urlParams = args["urlParams"] as? String {
            let script = "window.postMessage({ type: 'SET_PARAMS', params: '\(urlParams)' }, '*');"
            wv.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    func applyBackgroundStyle(_ style: String) {
        currentBackgroundStyle = style
        guard let window = pipWindow, let effect = visualEffectView else { return }

        switch style.lowercased() {
        case "glass", "window":
            effect.isHidden = false
            effect.material = .hudWindow
            effect.appearance = NSAppearance(named: .darkAqua)
            effect.layer?.borderWidth = 1.0
            effect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.22).cgColor
            window.backgroundColor = .clear
            window.hasShadow = true

        case "dark", "midnight":
            effect.isHidden = false
            effect.material = .popover
            effect.appearance = NSAppearance(named: .darkAqua)
            effect.layer?.borderWidth = 1.0
            effect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
            window.backgroundColor = .clear
            window.hasShadow = true

        case "light":
            effect.isHidden = false
            effect.material = .popover
            effect.appearance = NSAppearance(named: .aqua)
            effect.layer?.borderWidth = 1.0
            effect.layer?.borderColor = NSColor(white: 0.0, alpha: 0.12).cgColor
            window.backgroundColor = .clear
            window.hasShadow = true

        case "transparent":
            fallthrough
        default:
            effect.isHidden = true
            window.backgroundColor = .clear
            window.hasShadow = false
        }
    }

    func toggleBackgroundStyle() {
        let nextStyle = (currentBackgroundStyle == "transparent") ? "glass" : "transparent"
        applyBackgroundStyle(nextStyle)
        MainFlutterWindow.shared?.notifyPipBackgroundStyleChanged(nextStyle)
    }

    func showContextMenu(at event: NSEvent) {
        guard let view = webView else { return }
        let menu = NSMenu(title: "PiP Companion")

        let headerItem = NSMenuItem(title: "Window Background", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let transparentItem = NSMenuItem(title: "Transparent (Float on Desktop)", action: #selector(handleSelectTransparent), keyEquivalent: "")
        transparentItem.target = self
        transparentItem.state = (currentBackgroundStyle == "transparent") ? .on : .off
        menu.addItem(transparentItem)

        let glassItem = NSMenuItem(title: "Frosted Glass Window", action: #selector(handleSelectGlass), keyEquivalent: "")
        glassItem.target = self
        glassItem.state = (currentBackgroundStyle == "glass" || currentBackgroundStyle == "window") ? .on : .off
        menu.addItem(glassItem)

        let darkItem = NSMenuItem(title: "Dark Window", action: #selector(handleSelectDark), keyEquivalent: "")
        darkItem.target = self
        darkItem.state = (currentBackgroundStyle == "dark" || currentBackgroundStyle == "midnight") ? .on : .off
        menu.addItem(darkItem)

        let lightItem = NSMenuItem(title: "Light Window", action: #selector(handleSelectLight), keyEquivalent: "")
        lightItem.target = self
        lightItem.state = (currentBackgroundStyle == "light") ? .on : .off
        menu.addItem(lightItem)

        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: "Hide PiP", action: #selector(handleClosePip), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func handleSelectTransparent() {
        applyBackgroundStyle("transparent")
        MainFlutterWindow.shared?.notifyPipBackgroundStyleChanged("transparent")
    }

    @objc private func handleSelectGlass() {
        applyBackgroundStyle("glass")
        MainFlutterWindow.shared?.notifyPipBackgroundStyleChanged("glass")
    }

    @objc private func handleSelectDark() {
        applyBackgroundStyle("dark")
        MainFlutterWindow.shared?.notifyPipBackgroundStyleChanged("dark")
    }

    @objc private func handleSelectLight() {
        applyBackgroundStyle("light")
        MainFlutterWindow.shared?.notifyPipBackgroundStyleChanged("light")
    }

    @objc private func handleClosePip() {
        hidePipWindow()
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        NSLog("[PiPWindowManager] WKWebView didStartProvisionalNavigation: %@", webView.url?.absoluteString ?? "")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("[PiPWindowManager] WKWebView didFinish navigation: %@", webView.url?.absoluteString ?? "")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[PiPWindowManager] WKWebView didFail navigation: %@", error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("[PiPWindowManager] WKWebView didFailProvisionalNavigation: %@", error.localizedDescription)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        NSLog("[PiPWindowManager] WKWebView webContentProcessDidTerminate! Reloading...")
        webView.reload()
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "logging", let body = message.body as? String {
            NSLog("[PiPWeb] %@", body)
        }
    }
}

final class PiPPanel: NSPanel, NSWindowDelegate {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [
                .titled,
                .fullSizeContentView,
                .nonactivatingPanel,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        isReleasedWhenClosed  = false
        backgroundColor       = NSColor.clear
        isOpaque              = false
        hasShadow             = true
        level                 = .floating
        isFloatingPanel       = true
        hidesOnDeactivate     = false
        isMovableByWindowBackground = true
        collectionBehavior    = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        minSize = NSSize(width: 160, height: 160)
        maxSize = NSSize(width: 800, height: 800)

        delegate = self
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let clampedW = max(160, min(800, frameSize.width))
        let clampedH = max(160, min(800, frameSize.height))
        return NSSize(width: clampedW, height: clampedH)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        PiPWindowManager.shared.hidePipWindow()
        return false
    }
}

final class AvatarEditorWindowManager: NSObject, WKScriptMessageHandler, NSWindowDelegate {
    static let shared = AvatarEditorWindowManager()

    private var editorWindow: NSWindow?
    private var webView: WKWebView?
    private var onSaveCallback: ((String) -> Void)?

    func openEditor(editorUrl: String, parentWindow: NSWindow?, onSave: @escaping (String) -> Void) {
        self.onSaveCallback = onSave

        if let existing = editorWindow {
            if let url = URL(string: editorUrl) {
                webView?.load(URLRequest(url: url))
            }
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let width: CGFloat = 1120
        let height: CGFloat = 780
        let screenFrame = parentWindow?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2
        let frame = NSRect(x: x, y: y, width: width, height: height)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "OneWorks 3D Avatar Editor"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self

        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "onAvatarSaved")
        config.userContentController = userContentController

        let wv = WKWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: config)
        wv.autoresizingMask = [.width, .height]
        self.webView = wv

        if let url = URL(string: editorUrl) {
            wv.load(URLRequest(url: url))
        }

        window.contentView = wv
        self.editorWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "onAvatarSaved", let query = message.body as? String {
            onSaveCallback?(query)
        }
    }

    func windowWillClose(_ notification: Notification) {
        editorWindow = nil
        webView = nil
    }
}
