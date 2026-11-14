import Cocoa

public class NativeFlashReminderWindow: NSObject {
    public static let shared = NativeFlashReminderWindow()
    private var flashWindows: [NSWindow] = []
    private var generation = 0
    private var mouseMovementTimer: Timer?
    private var isDismissing = false
    
    public func triggerFlash(text: String, title: String = "A moment for you", reminderType: String = "", durationMs: Int = 250, opacity: CGFloat = 0.35, colorHex: String = "#000000", dismissOnMouseMove: Bool = false, textScale: CGFloat = 1, highContrast: Bool = false, reduceMotion: Bool = false) {
        dismissAll()
        let scale = textScale.isFinite ? min(1.5, max(1, textScale)) : 1
        let contrast = highContrast || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let minimalMotion = reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        generation += 1
        let current = generation
        isDismissing = false
        let initialMouseLocation = NSEvent.mouseLocation
        let shownAt = ProcessInfo.processInfo.systemUptime
        
        let active = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        for screen in [active].compactMap({ $0 }) {
            let window = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.setFrame(screen.frame, display: false)
            window.level = .statusBar
            window.hidesOnDeactivate = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            
            let card = HealthReminderCardView(
                title: title, message: text, reminderType: reminderType,
                dismissOnMouseMove: dismissOnMouseMove,
                width: min(520 * scale, screen.visibleFrame.width - 48),
                textScale: scale, highContrast: contrast)
            let size = NSSize(width: card.frame.width + 24, height: card.frame.height + 24)
            let container = NSView(frame: NSRect(origin: .zero, size: size))
            card.setFrameOrigin(NSPoint(x: 12, y: 12))
            container.addSubview(card)
            window.contentView = container
            window.setFrame(NSRect(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2,
                width: size.width, height: size.height), display: false)
            window.alphaValue = 0.0
            window.orderFrontRegardless()
            
            flashWindows.append(window)
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = minimalMotion ? 0 : 0.24
            for window in self.flashWindows {
                window.animator().alphaValue = 1.0
            }
        }, completionHandler: {
            guard self.generation == current, !self.isDismissing else { return }
            let fadeOut = { [weak self] in
                guard let self, self.generation == current, !self.isDismissing, !self.flashWindows.isEmpty else { return }
                self.isDismissing = true
                self.mouseMovementTimer?.invalidate()
                self.mouseMovementTimer = nil
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = minimalMotion ? 0 : 0.2
                    for window in self.flashWindows {
                        window.animator().alphaValue = 0.0
                    }
                }, completionHandler: {
                    guard self.generation == current else { return }
                    self.dismissAll()
                })
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationMs) / 1000.0, execute: fadeOut)
            if dismissOnMouseMove {
                // Polling also observes movement over our own windows and does not
                // depend on permission to monitor another application's input.
                let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] timer in
                    guard let self, self.generation == current else {
                        timer.invalidate()
                        return
                    }
                    guard ProcessInfo.processInfo.systemUptime - shownAt >= 0.35 else { return }
                    let position = NSEvent.mouseLocation
                    if hypot(position.x - initialMouseLocation.x,
                             position.y - initialMouseLocation.y) >= 3 {
                        fadeOut()
                    }
                }
                self.mouseMovementTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
        })
    }
    
    public func dismissAll() {
        generation += 1
        mouseMovementTimer?.invalidate()
        mouseMovementTimer = nil
        for window in flashWindows {
            window.orderOut(nil)
        }
        flashWindows.removeAll()
    }
}

/// Centered, readable reminder with one message and restrained styling.
final class HealthReminderCardView: NSView {
    init(title: String, message: String, reminderType: String,
         dismissOnMouseMove: Bool, width: CGFloat, textScale: CGFloat = 1, highContrast: Bool = false) {
        let font = NSFont.systemFont(ofSize: 20 * textScale, weight: .medium)
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = text.isEmpty ? title : text
        // Unknown/custom reminders have no arbitrary health icon. If an SF
        // Symbol is unavailable on this macOS version, omit it rather than
        // substituting an unrelated bell.
        let symbol: String?
        switch reminderType {
        case "eyeblink", "blink": symbol = "eye"
        case "hydration": symbol = "drop"
        case "posture": symbol = "figure.stand"
        case "stretch": symbol = "figure.cooldown"
        case "standup": symbol = "figure.walk"
        default: symbol = nil
        }
        let image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        let padding: CGFloat = 22
        let iconSize: CGFloat = 22 * textScale
        let gap: CGFloat = image == nil ? 0 : iconSize + 12
        let textX = padding + gap
        let horizontalInset = textX + padding
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2 * textScale
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: highContrast ? NSColor.white : NSColor(srgbRed: 0.83, green: 0.85, blue: 0.84, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let naturalWidth = ceil((content as NSString).size(withAttributes: attributes).width) + 4
        let textWidth = min(width - horizontalInset, naturalWidth)
        let cardWidth = textWidth + horizontalInset
        let measured = (content as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes).height
        let textHeight = min(86 * textScale, max(26 * textScale, ceil(measured) + 2))
        let height = max(iconSize, textHeight) + 40
        super.init(frame: NSRect(x: 0, y: 0, width: cardWidth, height: height))
        wantsLayer = true
        layer?.backgroundColor = highContrast ? NSColor.black.cgColor : NSColor(srgbRed: 0.14, green: 0.145, blue: 0.15, alpha: 1).cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = highContrast ? 1.5 : 0.5
        layer?.borderColor = NSColor.white.withAlphaComponent(highContrast ? 1 : 0.10).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.12
        layer?.shadowRadius = 5
        layer?.shadowOffset = NSSize(width: 0, height: -2)
        setAccessibilityElement(true)
        setAccessibilityLabel(content)

        if let image {
            let icon = NSImageView(frame: NSRect(
                x: padding, y: (height - iconSize) / 2,
                width: iconSize, height: iconSize))
            icon.image = image
            icon.contentTintColor = highContrast ? NSColor.white : NSColor(srgbRed: 0.64, green: 0.67, blue: 0.66, alpha: 1)
            icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20 * textScale, weight: .regular)
            addSubview(icon)
        }

        let label = NSTextField(wrappingLabelWithString: content)
        label.attributedStringValue = NSAttributedString(string: content, attributes: attributes)
        label.maximumNumberOfLines = 3
        label.lineBreakMode = .byWordWrapping
        label.frame = NSRect(x: textX, y: (height - textHeight) / 2,
                             width: textWidth, height: textHeight)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
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
        panel.hidesOnDeactivate = false
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
