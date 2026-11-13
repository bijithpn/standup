import Cocoa

public class NativeFlashReminderWindow: NSObject {
    public static let shared = NativeFlashReminderWindow()
    private var flashWindows: [NSWindow] = []
    
    public func triggerFlash(text: String, durationMs: Int = 250, opacity: CGFloat = 0.35, colorHex: String = "#000000") {
        dismissAll()
        
        let active = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        for screen in [active].compactMap({ $0 }) {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            
            let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor(flashHex: colorHex, alpha: opacity).cgColor
            
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: 26, weight: .bold)
            label.textColor = .white
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
            let hPad: CGFloat = 40
            let vPad: CGFloat = 26
            let maxWidth = min(720, screen.frame.width - 80)
            let textSize = label.sizeThatFits(NSSize(width: maxWidth - hPad * 2, height: .greatestFiniteMagnitude))
            let pillWidth = min(maxWidth, textSize.width + hPad * 2)
            let pillHeight = textSize.height + vPad * 2
            let pillRect = NSRect(
                x: (screen.frame.width - pillWidth) / 2,
                y: (screen.frame.height - pillHeight) / 2,
                width: pillWidth,
                height: pillHeight
            )

            let pillView = NSVisualEffectView(frame: pillRect)
            pillView.material = .hudWindow
            pillView.blendingMode = .behindWindow
            pillView.state = .active
            pillView.wantsLayer = true
            pillView.layer?.cornerRadius = pillHeight / 2
            pillView.layer?.masksToBounds = true
            pillView.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
            pillView.layer?.borderWidth = 1.0

            label.frame = NSRect(x: hPad, y: vPad, width: pillWidth - hPad * 2, height: textSize.height)
            pillView.addSubview(label)
            
            container.addSubview(pillView)
            
            window.contentView = container
            window.alphaValue = 0.0
            window.orderFrontRegardless()
            
            flashWindows.append(window)
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            for window in self.flashWindows {
                window.animator().alphaValue = 1.0
            }
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationMs) / 1000.0) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.12
                    for window in self.flashWindows {
                        window.animator().alphaValue = 0.0
                    }
                }, completionHandler: {
                    self.dismissAll()
                })
            }
        })
    }
    
    private func dismissAll() {
        for window in flashWindows {
            window.orderOut(nil)
        }
        flashWindows.removeAll()
    }
}

extension NSColor {
    convenience init(flashHex: String, alpha: CGFloat = 1.0) {
        var cString = flashHex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") { cString.removeFirst() }
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }
}

public class NativeToastWindow: NSObject {
    public static let shared = NativeToastWindow()
    private var window: NSPanel?
    private var generation = 0

    public func show(title: String, body: String, playSound: Bool) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        window?.orderOut(nil)

        let width: CGFloat = 340
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.preferredMaxLayoutWidth = width - 32

        let stack = NSStackView(views: [titleLabel, bodyLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        let height = stack.fittingSize.height

        let panel = NSPanel(
            contentRect: NSRect(x: screen.visibleFrame.maxX - width - 12, y: screen.visibleFrame.maxY - height - 12, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 14
        blur.layer?.masksToBounds = true
        stack.frame = blur.bounds
        blur.addSubview(stack)
        panel.contentView = blur

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.animator().alphaValue = 1
        window = panel
        if playSound { NSSound(named: "Glass")?.play() }

        generation += 1
        let current = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            guard let self, self.generation == current else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel.animator().alphaValue = 0 },
                                                 completionHandler: { panel.orderOut(nil) })
        }
    }
}
