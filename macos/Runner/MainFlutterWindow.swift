import Cocoa
import FlutterMacOS

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class OverlayWindowManager: NSObject {
    static let shared = OverlayWindowManager()
    
    private var overlayPanels: [NSScreen: OverlayPanel] = [:]
    private var flutterVC: FlutterViewController?
    private var originalWindow: NSWindow?
    private var originalWindowWasVisible: Bool = false
    private var mouseMonitor: Any?
    
    func showOverlay(args: [String: Any]? = nil) {
        if !overlayPanels.isEmpty { return }
        
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let mainWindow = appDelegate.mainFlutterWindow,
              let vc = mainWindow.contentViewController as? FlutterViewController else {
            return
        }
        
        self.originalWindow = mainWindow
        self.flutterVC = vc
        self.originalWindowWasVisible = mainWindow.isVisible
        
        // Remove from main window and hide it
        mainWindow.contentViewController = nil
        mainWindow.orderOut(nil)
        
        let screens = NSScreen.screens
        for screen in screens {
            let panel = createOverlayPanel(for: screen)
            overlayPanels[screen] = panel
            panel.alphaValue = 0.0
            panel.makeKeyAndOrderFront(nil)
        }
        
        updateActiveScreen()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            for panel in overlayPanels.values {
                panel.animator().alphaValue = 1.0
            }
        }
        
        // Monitor mouse movement to switch interactive UI between screens
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.updateActiveScreen()
            return event
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    func hideOverlay() {
        if overlayPanels.isEmpty { return }
        
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        
        let panels = Array(overlayPanels.values)
        overlayPanels.removeAll()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            for panel in panels {
                panel.animator().alphaValue = 0.0
            }
        }, completionHandler: {
            // Restore flutter VC to original window
            if let vc = self.flutterVC, let original = self.originalWindow {
                vc.view.removeFromSuperview()
                original.contentViewController = vc
                if self.originalWindowWasVisible {
                    original.makeKeyAndOrderFront(nil)
                }
            }
            
            for panel in panels {
                panel.orderOut(nil)
            }
            self.flutterVC = nil
            self.originalWindow = nil
        })
        
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    private func updateActiveScreen() {
        let mouseLocation = NSEvent.mouseLocation
        guard let activeScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }),
              let activePanel = overlayPanels[activeScreen],
              let vc = flutterVC else {
            return
        }
        
        if vc.view.window != activePanel {
            vc.view.removeFromSuperview()
            activePanel.contentView?.addSubview(vc.view)
            vc.view.frame = activePanel.contentView?.bounds ?? .zero
            vc.view.autoresizingMask = [.width, .height]
            activePanel.makeKey()
        }
    }
    
    func setClickThrough(_ enabled: Bool) {
        for panel in overlayPanels.values {
            panel.ignoresMouseEvents = enabled
        }
    }
    
    @objc private func screenParametersChanged() {
        hideOverlay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showOverlay()
        }
    }
    
    private func createOverlayPanel(for screen: NSScreen) -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        
        panel.contentView = visualEffectView
        panel.setFrame(screen.frame, display: true)
        
        return panel
    }
}

class MainFlutterWindow: NSWindow {
  private var bridgeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureBridge(binaryMessenger: flutterViewController.engine.binaryMessenger)

    self.isOpaque = false
    self.hasShadow = true
    self.backgroundColor = .clear
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    
    super.awakeFromNib()
  }

  private func configureBridge(binaryMessenger: FlutterBinaryMessenger) {
    bridgeChannel = FlutterMethodChannel(
      name: "com.breakmate.macos/bridge",
      binaryMessenger: binaryMessenger
    )

    bridgeChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "showOverlay":
        OverlayWindowManager.shared.showOverlay(args: call.arguments as? [String: Any])
        result(nil)

      case "hideOverlay":
        OverlayWindowManager.shared.hideOverlay()
        result(nil)

      case "setWindowLevel":
        if let args = call.arguments as? [String: Any],
           let level = args["level"] as? String {
          self.setNativeWindowLevel(level)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing level", details: nil))
        }

      case "getIdleTime":
        let anyEvent = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.combinedSessionState, eventType: anyEvent)
        result(idle)

      case "focusApp":
        NSApp.activate(ignoringOtherApps: true)
        result(nil)

      case "setIgnoreMouseEvents":
        if let args = call.arguments as? [String: Any], let ignore = args["ignore"] as? Bool {
          OverlayWindowManager.shared.setClickThrough(ignore)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing ignore parameter", details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setNativeWindowLevel(_ level: String) {
    switch level {
    case "screenSaver": self.level = .screenSaver
    case "floating": self.level = .floating
    default: self.level = .normal
    }
  }
}
