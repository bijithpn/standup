import Cocoa

public class NativeFlashReminderWindow: NSObject {
    public static let shared = NativeFlashReminderWindow()
    private var flashWindows: [NSWindow] = []
    
    public func triggerFlash(text: String, durationMs: Int = 250, opacity: CGFloat = 0.35, colorHex: String = "#000000") {
        dismissAll()
        
        for screen in NSScreen.screens {
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
            
            // Centered glass badge mimicking DeskRest's FullScreenFlashWindow
            let pillWidth: CGFloat = min(540, screen.frame.width - 80)
            let pillHeight: CGFloat = 84
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
            pillView.layer?.cornerRadius = 24
            pillView.layer?.masksToBounds = true
            pillView.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
            pillView.layer?.borderWidth = 1.0
            
            let label = NSTextField(frame: NSRect(x: 24, y: 18, width: pillWidth - 48, height: 48))
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.alignment = .center
            label.font = NSFont.systemFont(ofSize: 26, weight: .bold)
            label.textColor = .white
            label.stringValue = text
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
