
import Cocoa
import FlutterMacOS
import WebKit

final class PiPWindowManager: NSObject, WKNavigationDelegate {
    static let shared = PiPWindowManager()

    private var pipWindow: PiPPanel?
    private var webView: WKWebView?
    private var currentUrlStr: String?

    private override init() { super.init() }

    func showPipWindow(args: [String: Any]?) {
        let avatarUrlStr = (args?["avatarUrl"] as? String) ?? "http://127.0.0.1:5173/?companion=1#/companion"

        // If window already exists, sync settings or reload if needed
        if let window = pipWindow, webView != nil {
            syncSettings(args ?? [:])
            window.makeKeyAndOrderFront(nil)
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let w = min(max((args?["width"] as? Double) ?? 280, 200), 600)
        let h = min(max((args?["height"] as? Double) ?? 320, 200), 600)
        let x = (args?["x"] as? Double) ?? (screenFrame.maxX - w - 20)
        let y = (args?["y"] as? Double) ?? (screenFrame.minY + 20)

        let frame = NSRect(x: x, y: y, width: w, height: h)
        let window = PiPPanel(frame: frame)

        let webConfiguration = WKWebViewConfiguration()
        let wv = WKWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: webConfiguration)
        wv.autoresizingMask = [.width, .height]
        wv.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            wv.underPageBackgroundColor = .clear
        }
        wv.navigationDelegate = self

        currentUrlStr = avatarUrlStr
        if let url = URL(string: avatarUrlStr) {
            wv.load(URLRequest(url: url))
        }

        window.contentView = wv
        self.pipWindow = window
        self.webView = wv

        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            window.animator().alphaValue = 1.0
        }
    }

    func hidePipWindow() {
        guard let window = pipWindow, let wv = webView else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            window.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            wv.stopLoading()
            window.orderOut(nil)
            window.contentView = nil
            self?.pipWindow = nil
            self?.webView = nil
            self?.currentUrlStr = nil
        })
    }

    func syncSettings(_ args: [String: Any]) {
        guard let wv = webView else { return }

        if let urlParams = args["urlParams"] as? String {
            let script = "window.postMessage({ type: 'SET_PARAMS', params: '\(urlParams)' }, '*');"
            wv.evaluateJavaScript(script, completionHandler: nil)
        } else if let avatarUrlStr = args["avatarUrl"] as? String, avatarUrlStr != currentUrlStr {
            currentUrlStr = avatarUrlStr
            if let url = URL(string: avatarUrlStr) {
                wv.load(URLRequest(url: url))
            }
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
