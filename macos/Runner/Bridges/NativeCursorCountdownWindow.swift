import Cocoa

public class NativeCursorCountdownWindow: NSPanel {
    public static let shared = NativeCursorCountdownWindow()
    
    private var countdownField: NSTextField!
    private var mouseMonitor: Any?
    private var remainingSeconds = 15
    private var timer: Timer?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 72, height: 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true // Click-through so it never interrupts clicks
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        
        setupContent()
    }
    
    private func setupContent() {
        let contentRect = NSRect(x: 0, y: 0, width: 72, height: 28)
        let visualEffect = NSVisualEffectView(frame: contentRect)
        visualEffect.material = NSVisualEffectView.Material.hudWindow
        visualEffect.blendingMode = NSVisualEffectView.BlendingMode.behindWindow
        visualEffect.state = NSVisualEffectView.State.active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        visualEffect.layer?.borderWidth = 1.0
        
        countdownField = NSTextField(frame: NSRect(x: 0, y: 4, width: 72, height: 20))
        countdownField.isBezeled = false
        countdownField.drawsBackground = false
        countdownField.isEditable = false
        countdownField.alignment = .center
        countdownField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        countdownField.textColor = .white
        countdownField.stringValue = "● 15s"
        
        visualEffect.addSubview(countdownField)
        self.contentView = visualEffect
    }
    
    public func startCountdown(seconds: Int) {
        self.remainingSeconds = seconds
        self.countdownField.stringValue = "● \(seconds)s"
        updatePositionToCursor()
        
        self.alphaValue = 0.0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            self.animator().alphaValue = 1.0
        }
        
        // Track mouse movement
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
                self?.updatePositionToCursor()
            }
        }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingSeconds -= 1
            if self.remainingSeconds > 0 {
                self.countdownField.stringValue = "● \(self.remainingSeconds)s"
            } else {
                self.dismissCountdown()
            }
        }
    }
    
    private func updatePositionToCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let offset = CGPoint(x: mouseLocation.x + 18, y: mouseLocation.y - 36)
        self.setFrameOrigin(offset)
    }
    
    public func dismissCountdown() {
        timer?.invalidate()
        timer = nil
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}
