import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Configure window to stay in background - NOT on all desktops
    self.isOpaque = false
    self.hasShadow = true
    self.level = .normal  // Normal window level (not floating)
    self.collectionBehavior = [.managed, .moveToActiveSpace]  // Only show in current space
    self.isMovableByWindowBackground = false
    
    // Enable vibrancy (macOS acrylic-like effect)
    self.backgroundColor = NSColor.clear
    self.contentViewController?.view.wantsLayer = true
    
    // Set window to be transparent
    self.alphaValue = 1.0

    super.awakeFromNib()
  }

  /// Configure this window as a full-screen overlay
  func configureAsOverlay() {
    self.isOpaque = false
    self.hasShadow = false
    self.level = .screenSaver  // Higher level for overlay only
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    self.styleMask = [.borderless]
    self.isMovableByWindowBackground = false
    self.ignoresMouseEvents = false
    self.backgroundColor = NSColor.black.withAlphaComponent(0.95)
    
    // Ensure the content view covers the entire window
    if let screen = self.screen ?? NSScreen.main {
        self.setFrame(screen.frame, display: true)
    }
  }

  /// Configure this window to ignore mouse events (click-through)
  func setIgnoreMouseEvents(_ ignore: Bool) {
    self.ignoresMouseEvents = ignore
  }
  
  /// Reset window to normal state (background, not on top)
  func resetToNormal() {
    self.level = .normal  // Normal level - not on top
    self.collectionBehavior = [.managed, .moveToActiveSpace]  // Only current space
    self.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    self.isMovableByWindowBackground = true
    self.ignoresMouseEvents = false
    self.hasShadow = true
    self.backgroundColor = NSColor.windowBackgroundColor
    
    // Resize back to a reasonable size if it was full screen
    // or just let Flutter handle resizing via window_manager
  }
}
