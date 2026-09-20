
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

final class PiPWindowManager: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = PiPWindowManager()

    private var pipWindow: PiPPanel?
    private var webView: PiPWebView?
    private var containerView: NSView?
    private var visualEffectView: NSVisualEffectView?
    private var currentUrlStr: String?
    private var currentBackgroundStyle: String = "transparent"

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
                            user-select: none !important;
                            -webkit-user-select: none !important;
                        }

                        #avatar-camera-frame {
                            background: transparent !important;
                            background-color: transparent !important;
                            box-shadow: none !important;
                            border: none !important;
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
        }

        currentUrlStr = avatarUrlStr
        if let url = URL(string: avatarUrlStr) {
            NSLog("[PiPWindowManager] Loading URL: %@", url.absoluteString)
            wv.load(URLRequest(url: url))
        }

        window.setIsVisible(true)
        window.orderFrontRegardless()
    }

    func hidePipWindow() {
        guard let window = pipWindow, let wv = webView else { return }
        wv.stopLoading()
        window.orderOut(nil)
        window.contentView = nil
        self.pipWindow = nil
        self.webView = nil
        self.containerView = nil
        self.visualEffectView = nil
        self.currentUrlStr = nil
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
