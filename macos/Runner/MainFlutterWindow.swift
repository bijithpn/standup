import Cocoa
import FlutterMacOS

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class OverlayWindowManager: NSObject {
    static let shared = OverlayWindowManager()
    
    private var overlayInstances: [NSScreen: OverlayInstance] = [:]
    
    struct OverlayInstance {
        let window: OverlayPanel
        let engine: FlutterEngine
        let controller: FlutterViewController
    }
    
    func showOverlay(args: [String: Any]? = nil) {
        if !overlayInstances.isEmpty { return }
        
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let mainWindow = appDelegate.mainFlutterWindow else {
            return
        }
        
        // Hide main window
        mainWindow.orderOut(nil)
        
        let screens = NSScreen.screens
        for screen in screens {
            let instance = createOverlayInstance(for: screen, args: args)
            overlayInstances[screen] = instance
            
            instance.window.alphaValue = 0.0
            instance.window.makeKeyAndOrderFront(nil)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.4
                instance.window.animator().alphaValue = 1.0
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    func hideOverlay() {
        if overlayInstances.isEmpty { return }
        
        let instances = Array(overlayInstances.values)
        overlayInstances.removeAll()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            for instance in instances {
                instance.window.animator().alphaValue = 0.0
            }
        }, completionHandler: {
            // Restore main window visibility
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let mainWindow = appDelegate.mainFlutterWindow {
                mainWindow.makeKeyAndOrderFront(nil)
            }
            
            for instance in instances {
                instance.window.orderOut(nil)
                instance.engine.shutDownEngine()
            }
        })
        
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    func setClickThrough(_ enabled: Bool) {
        for instance in overlayInstances.values {
            instance.window.ignoresMouseEvents = enabled
        }
    }
    
    func updateData(_ data: [String: Any]) {
        for instance in overlayInstances.values {
            let channel = FlutterMethodChannel(name: "com.breakmate.macos/bridge", binaryMessenger: instance.engine.binaryMessenger)
            channel.invokeMethod("updateOverlayData", arguments: data)
        }
    }
    
    func updateVisualEffect(materialName: String) {
        for instance in overlayInstances.values {
            guard let visualEffectView = instance.window.contentView as? NSVisualEffectView else { continue }
            
            switch materialName {
            case "hud": visualEffectView.material = .hudWindow
            case "dark": visualEffectView.material = .hudWindow
            case "light": visualEffectView.material = .popover
            case "ultraDark": visualEffectView.material = .fullScreenUI
            case "fullScreenUI": visualEffectView.material = .fullScreenUI
            default: visualEffectView.material = .hudWindow
            }
        }
    }
    
    @objc private func screenParametersChanged() {
        hideOverlay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showOverlay()
        }
    }
    
    private func createOverlayInstance(for screen: NSScreen, args: [String: Any]?) -> OverlayInstance {
        let window = OverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = false
        
        // Ensure the window frame is exactly the screen frame
        window.setFrame(screen.frame, display: true)
        
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        
        // Spawn a fresh engine for each monitor to ensure simultaneous UI
        let engine = FlutterEngine(name: "OverlayEngine-\(UUID().uuidString)", project: nil, allowHeadlessExecution: true)
        engine.run(withEntrypoint: "overlayMain")
        RegisterGeneratedPlugins(registry: engine)
        
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        // CRITICAL: Ensure the Flutter view stretches to fill the visual effect view
        controller.view.autoresizingMask = [.width, .height]
        controller.view.frame = visualEffectView.bounds
        
        // Setup MethodChannel for this overlay
        let channel = FlutterMethodChannel(name: "com.breakmate.macos/bridge", binaryMessenger: engine.binaryMessenger)
        
        // Pass initial data if available
        if let args = args {
            channel.invokeMethod("updateOverlayData", arguments: args)
        }
        
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "hideOverlay":
                OverlayWindowManager.shared.hideOverlay()
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
        
        visualEffectView.addSubview(controller.view)
        window.contentView = visualEffectView
        
        return OverlayInstance(window: window, engine: engine, controller: controller)
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

      case "showCompanion":
        CompanionWindowManager.shared.showCompanion(args: call.arguments as? [String: Any])
        result(nil)

      case "hideCompanion":
        CompanionWindowManager.shared.hideCompanion()
        result(nil)

      case "setCompanionClickThrough":
        if let args = call.arguments as? [String: Any], let ignore = args["ignore"] as? Bool {
          CompanionWindowManager.shared.setClickThrough(ignore)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing ignore parameter", details: nil))
        }

      case "updateCompanionScale":
        if let args = call.arguments as? [String: Any], let scale = args["scale"] as? Double {
          CompanionWindowManager.shared.updateScale(scale)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing scale", details: nil))
        }

      case "updateCompanionTheme":
        if let args = call.arguments as? [String: Any], let themeId = args["themeId"] as? String {
          CompanionWindowManager.shared.updateTheme(themeId)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing themeId", details: nil))
        }

      case "updateCompanionName":
        if let args = call.arguments as? [String: Any], let petName = args["petName"] as? String {
          CompanionWindowManager.shared.updatePetName(petName)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing petName", details: nil))
        }

      case "triggerCompanionState":
        if let args = call.arguments as? [String: Any], let state = args["state"] as? String {
          CompanionWindowManager.shared.triggerState(state)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing state", details: nil))
        }

      case "setCompanionWandering":
        if let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool {
          CompanionWindowManager.shared.setWanderingEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing enabled", details: nil))
        }

      case "setCompanionFollowMouse":
        if let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool {
          CompanionWindowManager.shared.setFollowMouseEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing enabled", details: nil))
        }

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

      case "setVisualEffect":
        if let args = call.arguments as? [String: Any], let materialName = args["material"] as? String {
          OverlayWindowManager.shared.updateVisualEffect(materialName: materialName)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing material", details: nil))
        }

      case "setIgnoreMouseEvents":
        if let args = call.arguments as? [String: Any], let ignore = args["ignore"] as? Bool {
          OverlayWindowManager.shared.setClickThrough(ignore)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing ignore parameter", details: nil))
        }

      case "updateOverlayData":
        if let args = call.arguments as? [String: Any] {
          OverlayWindowManager.shared.updateData(args)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing data", details: nil))
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

  func triggerReopen() {
    bridgeChannel?.invokeMethod("handleReopen", arguments: nil)
  }
}
