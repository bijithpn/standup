import Cocoa

public class NativeCursorCountdownWindow: NSPanel {
    public static let shared = NativeCursorCountdownWindow()
    
    private let pillWidth: CGFloat = 64
    private let pillHeight: CGFloat = 26
    
    private var countdownField: NSTextField!
    private var dotView: NSView!
    private var mouseMonitor: Any?
    private var remainingSeconds = 15
    private var timer: Timer?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 64, height: 26),
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
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = pillHeight / 2.0
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        visualEffect.layer?.borderWidth = 1.0
        
        dotView = NSView()
        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = NSColor.systemOrange.cgColor
        dotView.layer?.cornerRadius = 3.0
        dotView.layer?.masksToBounds = true
        dotView.translatesAutoresizingMaskIntoConstraints = false
        
        countdownField = NSTextField()
        countdownField.isBezeled = false
        countdownField.drawsBackground = false
        countdownField.isEditable = false
        countdownField.isSelectable = false
        countdownField.alignment = .left
        countdownField.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        countdownField.textColor = .white
        countdownField.stringValue = "15s"
        countdownField.translatesAutoresizingMaskIntoConstraints = false
        countdownField.sizeToFit()
        
        let stackView = NSStackView(views: [dotView, countdownField])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 5.0
        stackView.distribution = .gravityAreas
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        visualEffect.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            dotView.widthAnchor.constraint(equalToConstant: 6.0),
            dotView.heightAnchor.constraint(equalToConstant: 6.0),
            
            stackView.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor)
        ])
        
        self.contentView = visualEffect
    }
    
    public func startCountdown(seconds: Int) {
        self.remainingSeconds = seconds
        self.countdownField.stringValue = "\(seconds)s"
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
                self.countdownField.stringValue = "\(self.remainingSeconds)s"
            } else {
                self.dismissCountdown()
            }
        }
    }
    
    private func updatePositionToCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let targetScreen = screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? screens.first
        
        guard let screen = targetScreen else {
            self.setFrameOrigin(CGPoint(x: mouseLocation.x + 16, y: mouseLocation.y - pillHeight - 12))
            return
        }
        
        let visible = screen.visibleFrame
        
        // Default placement: bottom-right of cursor arrow
        var targetX = mouseLocation.x + 16
        var targetY = mouseLocation.y - pillHeight - 12
        
        // If overflowing right edge of the screen, flip to the left of the cursor
        if targetX + pillWidth > visible.maxX {
            targetX = mouseLocation.x - pillWidth - 10
        }
        // If clamped beyond left edge
        if targetX < visible.minX + 4 {
            targetX = visible.minX + 4
        }
        
        // If overflowing bottom edge of the screen, flip above the cursor
        if targetY < visible.minY + 4 {
            targetY = mouseLocation.y + 16
        }
        // If overflowing top edge
        if targetY + pillHeight > visible.maxY - 4 {
            targetY = visible.maxY - pillHeight - 4
        }
        
        self.setFrameOrigin(CGPoint(x: targetX, y: targetY))
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
