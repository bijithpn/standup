
import Cocoa
import FlutterMacOS
import WebKit

final class PiPWindowManager: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = PiPWindowManager()

    private var pipWindow: PiPPanel?
    private var webView: WKWebView?
    private var currentUrlStr: String?

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
        userContentController.add(self, name: "logging")
        webConfiguration.userContentController = userContentController
        webConfiguration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let wv = WKWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: webConfiguration)
        wv.autoresizingMask = [.width, .height]
        wv.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            wv.underPageBackgroundColor = .clear
        }
        if #available(macOS 13.3, *) {
            wv.isInspectable = true
        }
        wv.wantsLayer = true
        wv.layer?.cornerRadius = 16
        wv.layer?.masksToBounds = true
        wv.navigationDelegate = self

        currentUrlStr = avatarUrlStr
        if let url = URL(string: avatarUrlStr) {
            NSLog("[PiPWindowManager] Loading URL: %@", url.absoluteString)
            wv.load(URLRequest(url: url))
        }

        window.contentView = wv
        self.pipWindow = window
        self.webView = wv

        window.alphaValue = 1.0
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
        self.currentUrlStr = nil
    }

    func syncSettings(_ args: [String: Any]) {
        guard let wv = webView else { return }

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

    override func mouseDragged(with event: NSEvent) {
        var origin = self.frame.origin
        origin.x += event.deltaX
        origin.y -= event.deltaY
        self.setFrameOrigin(origin)
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
