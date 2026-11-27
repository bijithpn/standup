import Cocoa
import CoreText
import FlutterMacOS
import Sparkle
import UserNotifications
import appkit_ui_element_colors
import audioplayers_darwin
import flutter_local_notifications
import macos_ui
import macos_window_utils
import package_info_plus
import screen_retriever_macos
import url_launcher_macos
import window_manager

/// Registers all required Flutter plugins for secondary engines (overlays, companion).
/// This now uses the standard GeneratedPluginRegistrant for 100% feature parity with the main engine.
/// Secondary isolates reuse these plugin instances to handle display queries, audio playback, and visual effects.
func RegisterSecondaryPlugins(registry: FlutterPluginRegistry, window: NSWindow? = nil) {
    // Register only the critical plugins required for secondary isolates (overlays and companion)
    // to keep memory and CPU footprint low on lower-end macOS devices.
    //
    // NOTE: WindowManagerPlugin is intentionally excluded here. Secondary engines are headless
    // (no NSWindow/view), so WindowManagerPlugin.mainWindow force-unwraps a nil view and
    // crashes the process the moment any window_manager Dart call reaches the secondary isolate.
    ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
    AudioplayersDarwinPlugin.register(with: registry.registrar(forPlugin: "AudioplayersDarwinPlugin"))
    // Secondary engines must not take notification clicks away from the main engine.
    let notificationDelegate = UNUserNotificationCenter.current().delegate
    FlutterLocalNotificationsPlugin.register(with: registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin"))
    UNUserNotificationCenter.current().delegate = notificationDelegate
    MacOSWindowUtilsPlugin.register(with: registry.registrar(forPlugin: "MacOSWindowUtilsPlugin"))
    
    WindowBridge.register(with: registry.registrar(forPlugin: "WindowBridge"), window: window)
    BehaviorEngineBridge.register(with: registry.registrar(forPlugin: "BehaviorEngineBridge"))
}

@main
class AppDelegate: FlutterAppDelegate, SPUUpdaterDelegate, SPUStandardUserDriverDelegate, UNUserNotificationCenterDelegate {
  static func main() {
    #if DEBUG
    DebugDisclaim.relaunchIfNeeded()
    #endif
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
  }

  var meetingBridge: MeetingDetectionBridge?
  var overlayBridge: OverlayWindowBridge?
  var windowBridge: WindowBridge?
  var sparkleBridge: SparkleBridge?
  var appTrackingBridge: AppTrackingBridge?
  
  override func applicationWillFinishLaunching(_ notification: Notification) {
    // Aggressively terminate any stale running instances of BreakMate (e.g. background menu bar process from a previous debug run)
    // to unlock the ObjectBox database, clean up the status bar, and enforce single-instance execution.
    let currentApp = NSRunningApplication.current
    let runningApps = NSWorkspace.shared.runningApplications
    let currentBundleId = currentApp.bundleIdentifier
    let currentProcessId = currentApp.processIdentifier
    
    var terminatedAny = false
    
    for app in runningApps {
      if app.processIdentifier == currentProcessId { continue }
      
      let isSameBundle = currentBundleId != nil && app.bundleIdentifier == currentBundleId
      if isSameBundle {
        NSLog("Terminating stale running instance of BreakMate (PID: \(app.processIdentifier), Name: \(app.localizedName ?? "unknown")) to release database lock")
        app.forceTerminate()
        terminatedAny = true
      }
    }
    
    // If we terminated another instance, wait briefly (500ms) to allow the OS kernel to fully clean up
    // the process and release POSIX file locks on the ObjectBox database files.
    if terminatedAny {
      Thread.sleep(forTimeInterval: 0.5)
    }
    
    super.applicationWillFinishLaunching(notification)
  }
  
  // The updater is started a couple of seconds after launch (see applicationDidFinishLaunching) so
  // Sparkle's setup does not sit on the main thread while the first window is being created.
  lazy var updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
  private var updaterStarted = false
  private let updateNotificationIdentifier = "com.breakmate.update-available"
  private let notifiedUpdateBuildKey = "BreakMateLastNotifiedUpdateBuild"
  private var pendingUpdateNotificationBuild: String?
  // Notification Center holds its delegate weakly. Retain the Flutter plugin
  // while forwarding reminder notifications to it.
  private var flutterNotificationDelegate: UNUserNotificationCenterDelegate?

  func installUpdateNotificationDelegate() {
    let center = UNUserNotificationCenter.current()
    if center.delegate !== self {
      flutterNotificationDelegate = center.delegate
      center.delegate = self
    }
  }

  var supportsGentleScheduledUpdateReminders: Bool { true }

  func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
    // Keep Sparkle's standard UI; notifications supplement background alerts.
    guard !state.userInitiated,
          UserDefaults.standard.string(forKey: notifiedUpdateBuildKey) != update.versionString,
          pendingUpdateNotificationBuild != update.versionString else { return }
    let build = update.versionString
    pendingUpdateNotificationBuild = build
    let center = UNUserNotificationCenter.current()
    // Reuses the same app permission as reminder notifications. A denial leaves
    // Sparkle's regular update window available and does not mark the build notified.
    center.requestAuthorization(options: [.alert]) { [weak self] granted, error in
      DispatchQueue.main.async {
        guard let self = self, self.pendingUpdateNotificationBuild == build else { return }
        guard granted else {
          self.pendingUpdateNotificationBuild = nil
          if let error = error { NSLog("Sparkle notification authorization failed: \(error)") }
          return
        }
        let content = UNMutableNotificationContent()
        content.title = "BreakMate update available"
        content.body = "Version \(update.displayVersionString) is ready. Click to review and install."
        content.userInfo = ["updateBuild": build]
        let request = UNNotificationRequest(identifier: self.updateNotificationIdentifier, content: content, trigger: nil)
        center.add(request) { error in
          DispatchQueue.main.async {
            if let error = error {
              NSLog("Sparkle notification failed: \(error)")
            } else {
              UserDefaults.standard.set(build, forKey: self.notifiedUpdateBuildKey)
            }
            // The update may have received attention while submission was in flight.
            if self.pendingUpdateNotificationBuild != build {
              center.removeDeliveredNotifications(withIdentifiers: [self.updateNotificationIdentifier])
            } else {
              self.pendingUpdateNotificationBuild = nil
            }
          }
        }
      }
    }
  }

  private func clearUpdateNotification() {
    pendingUpdateNotificationBuild = nil
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [updateNotificationIdentifier])
    center.removeDeliveredNotifications(withIdentifiers: [updateNotificationIdentifier])
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    clearUpdateNotification()
  }

  func standardUserDriverWillFinishUpdateSession() {
    clearUpdateNotification()
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    guard notification.request.identifier == updateNotificationIdentifier else {
      if let delegate = flutterNotificationDelegate,
         delegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
        delegate.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
      } else {
        completionHandler([])
      }
      return
    }
    if #available(macOS 11.0, *) {
      completionHandler([.banner, .list])
    } else {
      completionHandler([.alert])
    }
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    guard response.notification.request.identifier == updateNotificationIdentifier else {
      if let delegate = flutterNotificationDelegate,
         delegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
        delegate.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
      } else {
        completionHandler()
      }
      return
    }
    DispatchQueue.main.async { [weak self] in
      if let self = self, response.actionIdentifier == UNNotificationDefaultActionIdentifier {
        self.clearUpdateNotification()
        self.ensureUpdaterStarted()
        NSApp.activate(ignoringOtherApps: true)
        self.updaterController.checkForUpdates(nil)
      }
      completionHandler()
    }
  }

  /// Starts Sparkle once; safe to call from the launch timer and from a
  /// user-initiated check that arrives before the timer fires.
  func ensureUpdaterStarted() {
    guard !updaterStarted else { return }
    updaterStarted = true
    updaterController.startUpdater()
  }

  // Set once Sparkle is about to relaunch us after installing an update. The menu-bar
  // app (tray, prevent-close window, Dart exit handlers) can otherwise veto Sparkle's
  // quit request, leaving the update session open and the app never restarting.
  private var isInstallingUpdate = false

  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if isInstallingUpdate {
      return .terminateNow
    }
    return super.applicationShouldTerminate(sender)
  }

  func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
    NSLog("Sparkle: Relaunching to finish installing update")
    isInstallingUpdate = true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    // A finished/skipped break dismisses the overlay panels, which macOS can
    // report as a reopen. Don't open the app window because of that.
    let overlay = OverlayWindowManager.shared
    if overlay.isOverlayShowing || Date().timeIntervalSince(overlay.lastHideTime) < 2.0 {
      return true
    }
    if let window = mainFlutterWindow as? MainFlutterWindow {
      window.triggerReopen()
      window.showOnCurrentSpace()
    }
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    OverlayWindowManager.shared.destroyAllInstances()
    CompanionWindowManager.shared.hideCompanion()
    PiPFlutterWindowManager.shared.hidePipWindow()
    super.applicationWillTerminate(notification)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    installUpdateNotificationDelegate()
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
    let registrar = controller.registrar(forPlugin: "AppBridges")

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    NSLog("Sparkle: App Version: \(version) (\(build))")

    let feedUrl = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "NOT FOUND"

    let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? "NOT FOUND"
    NSLog("Sparkle: Configured with Feed URL: \(feedUrl)")
    NSLog("Sparkle: Configured with Public Key: \(publicKey)")

    meetingBridge = MeetingDetectionBridge(registrar: registrar)
      NativeSmartDetector.shared.register(with: registrar.messenger)

      let enhancementChannel = FlutterMethodChannel(name: "com.breakmate/native_enhancements", binaryMessenger: registrar.messenger)
      enhancementChannel.setMethodCallHandler { call, result in
          switch call.method {
          case "showTimerReturnPrompt":
              let args = call.arguments as? [String: Any]
              let remaining = max(0, args?["remainingSeconds"] as? Int ?? 0)
              let interval = max(1, args?["intervalMinutes"] as? Int ?? 20)
              let prompt = NativeReturnChoicePanel(remainingSeconds: remaining,
                  intervalMinutes: interval, theme: args?["theme"] as? [String: Any] ?? [:])
              result(prompt.show())
          case "showTrayDurationPicker":
              let args = call.arguments as? [String: Any]
              let picker = NativeTrayDurationPicker(
                  isFocus: args?["isFocus"] as? Bool ?? false,
                  initialMinutes: args?["initialMinutes"] as? Int ?? 15,
                  theme: args?["theme"] as? [String: Any] ?? [:])
              result(picker.show())
          case "showCursorCountdown":
              let seconds = (call.arguments as? [String: Any])?["seconds"] as? Int ?? 15
              NativeCursorCountdownWindow.shared.startCountdown(seconds: seconds)
              result(nil)
          case "hideCursorCountdown":
              NativeCursorCountdownWindow.shared.dismissCountdown()
              result(nil)
          case "dismissHealthReminder":
              NativeFlashReminderWindow.shared.dismissAll()
              result(nil)
          case "triggerFlashReminder":
              guard let args = call.arguments as? [String: Any],
                    let text = args["text"] as? String else {
                  result(FlutterError(code: "INVALID_ARGS", message: "text required", details: nil))
                  return
              }
              let duration = args["durationMs"] as? Int ?? 250
              let opacity = CGFloat(args["opacity"] as? Double ?? 0.35)
              let colorHex = args["colorHex"] as? String ?? "#000000"
              NativeFlashReminderWindow.shared.triggerFlash(text: text, title: args["title"] as? String ?? "A moment for you", reminderType: args["reminderType"] as? String ?? "", durationMs: duration, opacity: opacity, colorHex: colorHex, dismissOnMouseMove: args["dismissOnMouseMove"] as? Bool ?? false, textScale: CGFloat(args["textScale"] as? Double ?? 1), highContrast: args["highContrast"] as? Bool ?? false, reduceMotion: args["reduceMotion"] as? Bool ?? false)
              result(nil)
          case "showToast":
              let args = call.arguments as? [String: Any]
              NativeToastWindow.shared.show(title: args?["title"] as? String ?? "", body: args?["body"] as? String ?? "", playSound: args?["sound"] as? Bool ?? true)
              result(nil)
          case "preventDisplaySleep":
              let reason = (call.arguments as? [String: Any])?["reason"] as? String ?? "BreakMate Break Active"
              NativePowerAssertionManager.shared.preventDisplaySleep(reason: reason)
              result(nil)
          case "releaseDisplaySleep":
              NativePowerAssertionManager.shared.releaseDisplaySleep()
              result(nil)
          default:
              result(FlutterMethodNotImplemented)
          }
      }

      overlayBridge = OverlayWindowBridge(registrar: registrar)
      windowBridge = WindowBridge(registrar: registrar)
      sparkleBridge = SparkleBridge(registrar: registrar, updater: updaterController.updater, ensureStarted: { [weak self] in self?.ensureUpdaterStarted() })
      appTrackingBridge = AppTrackingBridge(registrar: registrar)
      NSLog("Sparkle: Initialized SparkleBridge with updater: \(updaterController.updater)")
    }
    
    super.applicationDidFinishLaunching(notification)
    NSLog("Sparkle: applicationDidFinishLaunching completed")

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      self?.ensureUpdaterStarted()
    }
    
    DispatchQueue.main.async { [weak self] in
      if let window = self?.mainFlutterWindow {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
      }
    }
    
    if let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu {
      let checkForUpdatesItem = NSMenuItem(
        title: "Check for Updates...",
        action: #selector(showSoftwareUpdate),
        keyEquivalent: ""
      )
      checkForUpdatesItem.target = self
      appMenu.insertItem(checkForUpdatesItem, at: 2)
    }
  }

    @objc private func showSoftwareUpdate() {
        sparkleBridge?.presentUpdatePanel()
    }

    // MARK: - SPUUpdaterDelegate
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        NSLog("Sparkle: Found valid update: \(item.displayVersionString) (\(item.versionString))")
        sparkleBridge?.updater(updater, didFindValidUpdate: item)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        NSLog("Sparkle: Did not find update")
        sparkleBridge?.updaterDidNotFindUpdate(updater)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        NSLog("Sparkle: Update aborted with error: \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }
    
    func updater(_ updater: SPUUpdater, didFailToRegisterUpdateWithItem item: SUAppcastItem, error: Error) {
        NSLog("Sparkle: Failed to register update \(item.displayVersionString): \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }
    
    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        NSLog("Sparkle: Failed to download update \(item.displayVersionString): \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }
    
    func updater(_ updater: SPUUpdater, didFailToInstallUpdate item: SUAppcastItem, error: Error) {
        NSLog("Sparkle: Failed to install update \(item.displayVersionString): \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }

    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        NSLog("Sparkle: Next update check scheduled in \(delay) seconds")
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        NSLog("Sparkle: Finished loading appcast with \(appcast.items.count) items")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        guard let error = error else { return }
        NSLog("Sparkle: Update check cycle failed: \(error.localizedDescription)")
        sparkleBridge?.updater(updater, didAbortWithError: error)
    }
}

/// A separate native window: never opens or attaches to the dashboard.
/// Uses the active Flutter theme while remaining independent of its windows.
private final class NativeReturnChoicePanel: NSObject, NSWindowDelegate {
    private let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 304),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
    private var choice: String?
    private var continueButton: DialogButton!
    private var restartButton: DialogButton!
    private var laterButton: DialogButton!
    private let remainingLabel = NSTextField(labelWithString: "")

    init(remainingSeconds: Int, intervalMinutes: Int, theme: [String: Any]) {
        super.init()
        let background = ActiveDialog.color(theme, "background", .windowBackgroundColor)
        let surface = ActiveDialog.color(theme, "surface", .controlBackgroundColor)
        let border = ActiveDialog.color(theme, "border", .separatorColor)
        let foreground = ActiveDialog.color(theme, "foreground", .labelColor)
        let secondary = ActiveDialog.color(theme, "secondary", .secondaryLabelColor)
        let accent = ActiveDialog.color(theme, "accent", .controlAccentColor)
        let onAccent = ActiveDialog.color(theme, "onAccent", .white)
        panel.title = "Timer paused"
        panel.delegate = self
        ActiveDialog.configure(panel, theme: theme)
        guard let content = panel.contentView else { return }
        func label(_ text: String, frame: NSRect, size: CGFloat, color: NSColor,
                   weight: NSFont.Weight = .regular) {
            let field = NSTextField(labelWithString: text)
            field.frame = frame
            field.font = ActiveDialog.font(size, weight: weight)
            field.textColor = color
            content.addSubview(field)
        }
        label("Paused while away", frame: NSRect(x: 24, y: 248, width: 332, height: 32),
              size: 22, color: foreground, weight: .semibold)
        label("Your break timer is on hold", frame: NSRect(x: 24, y: 220, width: 332, height: 20),
              size: 12, color: secondary)
        let card = NSView(frame: NSRect(x: 24, y: 108, width: 332, height: 96))
        card.wantsLayer = true
        card.layer?.backgroundColor = surface.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = border.cgColor
        content.addSubview(card)
        remainingLabel.stringValue = String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
        remainingLabel.frame = NSRect(x: 40, y: 140, width: 300, height: 52)
        remainingLabel.font = ActiveDialog.font(44, weight: .medium)
        remainingLabel.textColor = foreground
        remainingLabel.setAccessibilityLabel("\(remainingSeconds / 60) minutes \(remainingSeconds % 60) seconds remaining")
        content.addSubview(remainingLabel)
        label("Remaining until your next break", frame: NSRect(x: 40, y: 120, width: 300, height: 16),
              size: 11, color: secondary)
        label("Start over begins a fresh \(intervalMinutes)-minute interval",
              frame: NSRect(x: 24, y: 76, width: 332, height: 16), size: 11, color: secondary)
        laterButton = DialogButton(title: "Not now", background: background, foreground: secondary, border: background)
        restartButton = DialogButton(title: "Start over", background: surface, foreground: foreground, border: border)
        continueButton = DialogButton(title: "Continue", background: accent, foreground: onAccent, border: accent)
        for (button, frame, action) in [
            (laterButton!, NSRect(x: 24, y: 24, width: 84, height: 36), #selector(dismiss)),
            (restartButton!, NSRect(x: 116, y: 24, width: 112, height: 36), #selector(restart)),
            (continueButton!, NSRect(x: 236, y: 24, width: 120, height: 36), #selector(resume))] {
            button.frame = frame
            button.target = self
            button.action = action
            content.addSubview(button)
        }
        continueButton.keyEquivalent = "\r"
        laterButton.keyEquivalent = "\u{1b}"
        panel.defaultButtonCell = continueButton.cell as? NSButtonCell
        panel.initialFirstResponder = continueButton
        continueButton.nextKeyView = restartButton
        restartButton.nextKeyView = laterButton
        laterButton.nextKeyView = continueButton
    }

    @objc private func resume() { choice = "continue"; NSApp.stopModal(withCode: .OK) }
    @objc private func restart() { choice = "restart"; NSApp.stopModal(withCode: .OK) }
    @objc private func dismiss() { choice = nil; NSApp.stopModal(withCode: .cancel) }

    func windowShouldClose(_ sender: NSWindow) -> Bool { dismiss(); return false }

    func show() -> String? {
        ActiveDialog.show(panel)
        defer { panel.orderOut(nil) }
        _ = NSApp.runModal(for: panel)
        return choice
    }
}

/// Flat app-colored controls with native mouse, keyboard and accessibility behavior.
private final class DialogButton: NSButton {
    private let fill: NSColor
    private let ink: NSColor
    private let outline: NSColor
    private var hovering = false
    private var hoverArea: NSTrackingArea?

    init(title: String, background: NSColor, foreground: NSColor, border: NSColor) {
        fill = background; ink = foreground; outline = border
        super.init(frame: .zero)
        self.title = title
        font = ActiveDialog.font(12, weight: .semibold)
        isBordered = false
        focusRingType = .none
        setButtonType(.momentaryPushIn)
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder(); needsDisplay = true; return accepted
    }
    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder(); needsDisplay = true; return accepted
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverArea { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        let paint = (hovering || isHighlighted) ? fill.blended(withFraction: isHighlighted ? 0.16 : 0.08, of: ink) ?? fill : fill
        paint.setFill(); path.fill()
        outline.setStroke(); path.lineWidth = 1; path.stroke()
        if window?.firstResponder === self {
            ink.withAlphaComponent(0.7).setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 6, yRadius: 6)
            ring.lineWidth = 1; ring.stroke()
        }
        let text = NSAttributedString(string: title, attributes: [.font: font!, .foregroundColor: isEnabled ? ink : ink.withAlphaComponent(0.35)])
        let size = text.size()
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }
}

/// A nonactivating panel can become key without switching away from a fullscreen Space.
private enum ActiveDialog {
    private static var fontsLoaded = false

    static func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if !fontsLoaded {
            fontsLoaded = true
            if let frameworks = Bundle.main.privateFrameworksURL {
                let directory = frameworks.appendingPathComponent("App.framework/Resources/flutter_assets/assets/fonts/Inter")
                for name in ["Inter-Regular", "Inter-Medium", "Inter-SemiBold"] {
                    let url = directory.appendingPathComponent("\(name).ttf")
                    if FileManager.default.fileExists(atPath: url.path) {
                        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                    }
                }
            }
        }
        let name = weight == .semibold ? "Inter-SemiBold" : weight == .medium ? "Inter-Medium" : "Inter-Regular"
        return NSFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    static func configure(_ panel: NSPanel, theme: [String: Any]) {
        panel.styleMask.insert(.nonactivatingPanel)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.level = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: (theme["isDark"] as? Bool ?? true) ? .darkAqua : .aqua)
        panel.backgroundColor = color(theme, "background", .windowBackgroundColor)
    }

    static func color(_ theme: [String: Any], _ key: String, _ fallback: NSColor) -> NSColor {
        guard let value = (theme[key] as? NSNumber)?.uint32Value else { return fallback }
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: CGFloat((value >> 24) & 255) / 255)
    }

    static func show(_ panel: NSWindow) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let area = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: area.midX - panel.frame.width / 2,
                                         y: area.midY - panel.frame.height / 2))
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }
}

private final class NativeTrayDurationPicker: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 380, height: 304),
        styleMask: [.titled, .closable], backing: .buffered, defer: false)
    private let hours = NSTextField(frame: NSRect(x: 20, y: 88, width: 104, height: 30))
    private let minutes = NSTextField(frame: NSRect(x: 170, y: 88, width: 104, height: 30))
    private var startButton: DialogButton!
    private var secondaryColor = NSColor.secondaryLabelColor
    private let hint = NSTextField(labelWithString: "Reminders resume automatically.")

    init(isFocus: Bool, initialMinutes: Int, theme: [String: Any]) {
        super.init()
        panel.title = isFocus ? "Focus Mode" : "Snooze"
        panel.delegate = self
        ActiveDialog.configure(panel, theme: theme)
        let foreground = ActiveDialog.color(theme, "foreground", .labelColor)
        secondaryColor = ActiveDialog.color(theme, "secondary", .secondaryLabelColor)
        let surface = ActiveDialog.color(theme, "surface", .controlBackgroundColor)
        let border = ActiveDialog.color(theme, "border", .separatorColor)
        let accent = ActiveDialog.color(theme, "accent", .controlAccentColor)
        startButton = DialogButton(title: isFocus ? "Start focus" : "Snooze reminders",
            background: accent, foreground: ActiveDialog.color(theme, "onAccent", .white), border: accent)
        guard let content = panel.contentView else { return }
        let title = NSTextField(labelWithString: isFocus ? "Focus mode" : "Snooze reminders")
        title.frame = NSRect(x: 24, y: 248, width: 332, height: 32)
        title.font = ActiveDialog.font(22, weight: .semibold)
        title.textColor = foreground
        content.addSubview(title)
        let card = NSView(frame: NSRect(x: 24, y: 104, width: 332, height: 100))
        card.wantsLayer = true
        card.layer?.backgroundColor = surface.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = border.cgColor
        content.addSubview(card)
        let description = NSTextField(wrappingLabelWithString: isFocus
            ? "Pause break reminders while you focus."
            : "Choose how long to pause break reminders.")
        description.frame = NSRect(x: 24, y: 220, width: 332, height: 20)
        description.font = ActiveDialog.font(12)
        description.textColor = secondaryColor
        content.addSubview(description)
        for (text, x) in [("Hours", CGFloat(40)), ("Minutes", CGFloat(198))] {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: x, y: 172, width: 142, height: 16)
            label.font = ActiveDialog.font(11, weight: .medium)
            label.textColor = secondaryColor
            content.addSubview(label)
        }
        hours.frame = NSRect(x: 40, y: 124, width: 142, height: 32)
        minutes.frame = NSRect(x: 198, y: 124, width: 142, height: 32)
        let initial = min(1439, max(1, initialMinutes))
        hours.stringValue = String(initial / 60)
        minutes.stringValue = String(initial % 60)
        for (field, label) in [(hours, "Hours"), (minutes, "Minutes")] {
            field.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
            field.focusRingType = .none
            field.textColor = foreground
            field.backgroundColor = ActiveDialog.color(theme, "background", .textBackgroundColor)
            field.alignment = .center
            field.bezelStyle = .roundedBezel
            field.delegate = self
            field.setAccessibilityLabel(label)
            content.addSubview(field)
        }
        hint.frame = NSRect(x: 24, y: 76, width: 332, height: 16)
        hint.font = ActiveDialog.font(11)
        hint.textColor = secondaryColor
        content.addSubview(hint)
        let cancel = DialogButton(title: "Cancel", background: surface, foreground: foreground, border: border)
        cancel.target = self
        cancel.action = #selector(cancelSelection)
        cancel.frame = NSRect(x: 24, y: 24, width: 104, height: 36)
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        content.addSubview(cancel)
        startButton.frame = NSRect(x: 140, y: 24, width: 216, height: 36)
        startButton.bezelStyle = .rounded
        startButton.target = self
        startButton.action = #selector(startSelection)
        startButton.keyEquivalent = "\r"
        content.addSubview(startButton)
        panel.defaultButtonCell = startButton.cell as? NSButtonCell
        panel.initialFirstResponder = minutes
        hours.nextKeyView = minutes
        minutes.nextKeyView = cancel
        cancel.nextKeyView = startButton
        startButton.nextKeyView = hours
        durationChanged()
    }

    private var selectedDuration: Int? {
        guard let h = Int(hours.stringValue), (0...23).contains(h),
              let m = Int(minutes.stringValue), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }

    private func durationChanged() {
        let duration = selectedDuration
        startButton.isEnabled = (duration ?? 0) > 0
        if duration == nil {
            hint.stringValue = "Use 0–23 hours and 0–59 minutes."
        } else if duration == 0 {
            hint.stringValue = "Choose at least one minute."
        } else {
            hint.stringValue = "Reminders resume in \(duration! / 60)h \(duration! % 60)m."
        }
        hint.textColor = startButton.isEnabled ? secondaryColor : NSColor.systemRed.blended(withFraction: 0.15, of: secondaryColor) ?? .systemRed
    }

    func controlTextDidChange(_ notification: Notification) { durationChanged() }

    @objc private func startSelection() {
        guard let duration = selectedDuration, duration > 0 else { return }
        NSApp.stopModal(withCode: .OK)
    }

    @objc private func cancelSelection() { NSApp.stopModal(withCode: .cancel) }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancelSelection()
        return false
    }

    func show() -> Int? {
        ActiveDialog.show(panel)
        defer { panel.orderOut(nil) }
        guard NSApp.runModal(for: panel) == .OK else { return nil }
        return selectedDuration
    }
}

/// Own the checking/result UI; Sparkle continues to own signed downloads and installation.
private final class NativeUpdatePanel: NSObject, NSWindowDelegate {
    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 232),
                        styleMask: [.titled, .closable], backing: .buffered, defer: false)
    private let heading = NSTextField(labelWithString: "Checking for updates")
    private let detail = NSTextField(wrappingLabelWithString: "Connecting to the update server…")
    private let spinner = NSProgressIndicator()
    private let button: DialogButton
    var install: (() -> Void)?
    var dismissed: (() -> Void)?
    private var hasUpdate = false

    init(theme: [String: Any]) {
        let accent = ActiveDialog.color(theme, "accent", .controlAccentColor)
        button = DialogButton(title: "Cancel", background: accent,
            foreground: ActiveDialog.color(theme, "onAccent", .white), border: accent)
        super.init()
        ActiveDialog.configure(panel, theme: theme)
        panel.title = "Software Update"
        panel.delegate = self
        guard let content = panel.contentView else { return }
        heading.frame = NSRect(x: 24, y: 176, width: 352, height: 32)
        heading.font = ActiveDialog.font(22, weight: .semibold)
        heading.textColor = ActiveDialog.color(theme, "foreground", .labelColor)
        detail.frame = NSRect(x: 24, y: 96, width: 352, height: 64)
        detail.font = ActiveDialog.font(13)
        detail.textColor = ActiveDialog.color(theme, "secondary", .secondaryLabelColor)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.frame = NSRect(x: 24, y: 32, width: 20, height: 20)
        spinner.setAccessibilityLabel("Checking for updates")
        spinner.startAnimation(nil)
        button.frame = NSRect(x: 160, y: 24, width: 216, height: 36)
        button.target = self
        button.action = #selector(act)
        button.keyEquivalent = "\r"
        for view in [heading, detail, spinner, button] { content.addSubview(view) }
        panel.defaultButtonCell = button.cell as? NSButtonCell
        panel.initialFirstResponder = button
    }

    func finish(version: String? = nil, error: String? = nil) {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        hasUpdate = version != nil
        heading.stringValue = error != nil ? "Couldn’t check for updates" : hasUpdate ? "An update is ready" : "You’re up to date"
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        detail.stringValue = error ?? (version.map { "BreakMate \($0) is available. Review the release notes and install in the next step." }
            ?? "You’re running BreakMate \(current). No newer compatible version is available.")
        button.title = hasUpdate ? "Review update" : "Done"
        button.setAccessibilityLabel(button.title)
        button.needsDisplay = true
        heading.setAccessibilityValue(heading.stringValue)
        NSAccessibility.post(element: heading, notification: .valueChanged)
    }

    @objc private func act() {
        panel.orderOut(nil)
        if hasUpdate { install?() }
        dismissed?()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panel.orderOut(nil)
        dismissed?()
        return false
    }
    func show() { ActiveDialog.show(panel) }
}

// MARK: - WindowBridge

class WindowBridge: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private weak var registrar: FlutterPluginRegistrar?
    private weak var targetWindow: NSWindow?
    
    /// Whether this bridge may act on the app's main window when its own
    /// engine has no window attached.
    ///
    /// True for the main engine, where "the window" and "the app's window" are
    /// the same thing. False for every secondary engine — see `window`.
    private let allowsAppWindowFallback: Bool

    /// Secondary engines (companion, PiP, overlays) register through here.
    static func register(with registrar: FlutterPluginRegistrar) {
        register(with: registrar, window: nil)
    }

    static func register(with registrar: FlutterPluginRegistrar, window: NSWindow?) {
        let bridge = WindowBridge(registrar: registrar, allowsAppWindowFallback: false, targetWindow: window)
        registrar.addMethodCallDelegate(bridge, channel: bridge.channel)
    }

    init(registrar: FlutterPluginRegistrar, allowsAppWindowFallback: Bool = true, targetWindow: NSWindow? = nil) {
        self.registrar = registrar
        self.targetWindow = targetWindow
        self.allowsAppWindowFallback = allowsAppWindowFallback
        channel = FlutterMethodChannel(
            name: "com.breakmate/window",
            binaryMessenger: registrar.messenger
        )
        super.init()
        registrar.addMethodCallDelegate(self, channel: channel)
    }

    /// The window this bridge is allowed to touch.
    ///
    /// A secondary engine owns exactly one window, and if that window is not
    /// attached yet there is simply nothing to act on. Falling back to the
    /// app's main window here would be actively harmful now that the companion
    /// moves its own window around the screen: a failed lookup in the PiP
    /// engine would send the user's main BreakMate window wandering off
    /// instead of the pet.
    private var window: NSWindow? {
        if let targetWindow = targetWindow { return targetWindow }
        if let own = registrar?.view?.window { return own }
        guard allowsAppWindowFallback else {
            // Logged once rather than per call: the companion asks to be moved
            // twenty-five times a second while it walks, and this is the one
            // thing that would make that silently do nothing.
            if !hasWarnedAboutMissingWindow {
                hasWarnedAboutMissingWindow = true
                NSLog("WindowBridge: secondary engine has no window attached; window calls are being ignored")
            }
            return nil
        }
        return NSApp.mainWindow ?? NSApp.keyWindow
    }

    private var hasWarnedAboutMissingWindow = false
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        
        switch call.method {
        case "setWindowLevel":
            handleSetWindowLevel(args: args, result: result)
        case "setWindowPosition":
            handleSetWindowPosition(args: args, result: result)
        case "getWindowPosition":
            handleGetWindowPosition(result: result)
        case "setWindowOpacity":
            handleSetWindowOpacity(args: args, result: result)
        case "setIgnoresMouseEvents":
            handleSetIgnoresMouseEvents(args: args, result: result)
        case "setHasShadow":
            handleSetHasShadow(args: args, result: result)
        case "setAcceptsMouseMovedEvents":
            handleSetAcceptsMouseMovedEvents(args: args, result: result)
        case "orderFrontRegardless":
            handleOrderFrontRegardless(result: result)
        case "hideWindow":
            handleHideWindow(result: result)
        case "showWindow":
            handleShowWindow(result: result)
        case "setWindowStyle":
            handleSetWindowStyle(args: args, result: result)
        case "setWindowSize":
            handleSetWindowSize(args: args, result: result)
        case "startDrag":
            handleStartDrag(result: result)
        case "setNonActivating":
            handleSetNonActivating(args: args, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleSetWindowLevel(args: [String: Any]?, result: FlutterResult) {
        guard let levelStr = args?["level"] as? String,
              let window = self.window else {
            result(nil)
            return
        }
        
        switch levelStr {
        case "floating": window.level = .floating
        case "normal": window.level = .normal
        case "statusBar": window.level = .statusBar
        case "modalPanel": window.level = .modalPanel
        case "popUpMenu": window.level = .popUpMenu
        case "screenSaver": window.level = .screenSaver
        default: break
        }
        result(nil)
    }
    
    private func handleSetWindowPosition(args: [String: Any]?, result: FlutterResult) {
        guard let x = args?["x"] as? Double,
              let y = args?["y"] as? Double,
              let window = self.window else {
            result(nil)
            return
        }
        
        var frame = window.frame
        frame.origin.x = x
        frame.origin.y = y
        // `animate: true` runs a nested run loop until AppKit's animation
        // finishes. That is right for a one-off move and ruinous for the
        // companion's wandering, which sets a new position twenty-five times a
        // second: every call would block the main thread, and each animation
        // would be fighting the one before it. Callers driving their own
        // motion pass false and get an immediate move.
        let animate = args?["animate"] as? Bool ?? true
        window.setFrame(frame, display: true, animate: animate)
        result(nil)
    }
    
    private func handleGetWindowPosition(result: FlutterResult) {
        guard let window = self.window else {
            result(["x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0])
            return
        }
        result([
            "x": window.frame.origin.x,
            "y": window.frame.origin.y,
            "width": Double(window.frame.size.width),
            "height": Double(window.frame.size.height)
        ])
    }
    
    private func handleSetWindowOpacity(args: [String: Any]?, result: FlutterResult) {
        guard let opacity = args?["opacity"] as? Double,
              let window = self.window else {
            result(nil)
            return
        }
        window.alphaValue = CGFloat(opacity)
        result(nil)
    }
    
    private func handleSetIgnoresMouseEvents(args: [String: Any]?, result: FlutterResult) {
        guard let ignore = args?["ignore"] as? Bool,
              let window = self.window else {
            result(nil)
            return
        }
        window.ignoresMouseEvents = ignore
        result(nil)
    }
    
    private func handleSetHasShadow(args: [String: Any]?, result: FlutterResult) {
        guard let hasShadow = args?["hasShadow"] as? Bool,
              let window = self.window else {
            result(nil)
            return
        }
        window.hasShadow = hasShadow
        result(nil)
    }
    
    private func handleSetAcceptsMouseMovedEvents(args: [String: Any]?, result: FlutterResult) {
        guard let accept = args?["accept"] as? Bool,
              let window = self.window else {
            result(nil)
            return
        }
        window.acceptsMouseMovedEvents = accept
        result(nil)
    }
    
    private func handleOrderFrontRegardless(result: FlutterResult) {
        guard let window = self.window else {
            result(nil)
            return
        }
        window.orderFrontRegardless()
        result(nil)
    }
    
    private func handleHideWindow(result: FlutterResult) {
        guard let window = self.window else {
            result(nil)
            return
        }
        window.orderOut(nil)
        result(nil)
    }
    
    private func handleShowWindow(result: FlutterResult) {
        guard let window = self.window else {
            result(nil)
            return
        }
        (window as? MainFlutterWindow)?.showOnCurrentSpace()
        if !(window is MainFlutterWindow) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        result(nil)
    }
    
    private func handleSetWindowStyle(args: [String: Any]?, result: FlutterResult) {
        guard let style = args?["style"] as? String,
              let window = self.window else {
            result(nil)
            return
        }
        
        switch style {
        case "borderless": window.styleMask = [.borderless, .nonactivatingPanel]
        case "titled": window.styleMask = [.titled, .closable, .miniaturizable]
        case "utility": window.styleMask = [.titled, .closable, .utilityWindow]
        case "hud": window.styleMask = [.titled, .closable, .hudWindow]
        default: break
        }
        result(nil)
    }

    private func handleSetWindowSize(args: [String: Any]?, result: FlutterResult) {
        guard let width = args?["width"] as? Double,
              let height = args?["height"] as? Double,
              let window = self.window else {
            result(nil)
            return
        }
        var frame = window.frame
        let deltaY = frame.size.height - CGFloat(height)
        frame.origin.y += deltaY
        frame.size.width = CGFloat(width)
        frame.size.height = CGFloat(height)
        window.setFrame(frame, display: true, animate: true)
        result(nil)
    }

    private func handleStartDrag(result: FlutterResult) {
        guard let window = self.window else {
            result(nil)
            return
        }
        if let event = NSApp.currentEvent {
            window.performDrag(with: event)
        }
        result(nil)
    }

    private func handleSetNonActivating(args: [String: Any]?, result: FlutterResult) {
        guard let nonActivating = args?["nonActivating"] as? Bool,
              let window = self.window else {
            result(nil)
            return
        }
        if nonActivating {
            window.styleMask.insert(.nonactivatingPanel)
        } else {
            window.styleMask.remove(.nonactivatingPanel)
        }
        result(nil)
    }
}

// MARK: - SparkleBridge

class SparkleBridge: NSObject {
    private let channel: FlutterMethodChannel
    private let updater: SPUUpdater
    private let ensureStarted: () -> Void
    private var lastDialogTheme: [String: Any] = [:]
    func presentUpdatePanel() { showUpdatePanel(theme: lastDialogTheme) }
    private var updatePanel: NativeUpdatePanel?
    private var panelTimeout: DispatchWorkItem?
    private var panelCheckPending = false
    private var sparkleWindowObserver: NSObjectProtocol?

    private func showUpdatePanel(theme: [String: Any]) {
        lastDialogTheme = theme
        if let panel = updatePanel { panel.show(); return }
        let panel = NativeUpdatePanel(theme: theme)
        updatePanel = panel
        panelCheckPending = true
        panel.install = { [weak self] in self?.startVisibleUpdate() }
        panel.dismissed = { [weak self] in
            guard let self = self, !self.panelCheckPending else { return }
            self.updatePanel = nil
        }
        panel.show()
        let timeout = DispatchWorkItem { [weak self] in
            self?.panelCheckPending = false
            self?.updatePanel?.finish(error: "The server did not respond. Check your connection and try again.")
        }
        panelTimeout?.cancel()
        panelTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
        ensureStarted()
        startInformationalCheck(attemptsLeft: 20) { [weak self] result in
            if let error = result as? FlutterError {
                self?.finishPanel(error: error.message ?? "Please try again.")
            }
        }
    }

    private func finishPanel(version: String? = nil, error: String? = nil) {
        guard panelCheckPending else { return }
        panelCheckPending = false
        panelTimeout?.cancel()
        updatePanel?.finish(version: version, error: error)
    }

    private func startVisibleUpdate() {
        // Only Sparkle-owned windows are adjusted; never move the dashboard or overlays.
        if sparkleWindowObserver == nil {
            sparkleWindowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification, object: nil, queue: .main
            ) { notification in
                guard let window = notification.object as? NSWindow,
                      (Bundle(for: type(of: window)).bundleIdentifier == "org.sparkle-project.Sparkle" ||
                       window.windowController.map { Bundle(for: type(of: $0)).bundleIdentifier == "org.sparkle-project.Sparkle" } == true),
                      window.isVisible,
                      !window.collectionBehavior.contains(.canJoinAllSpaces) else { return }
                window.collectionBehavior.remove(.moveToActiveSpace)
                window.collectionBehavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary])
                window.level = .modalPanel
                ActiveDialog.show(window)
            }
        }
        ensureStarted()
        updater.checkForUpdates()
    }
    
    init(registrar: FlutterPluginRegistrar, updater: SPUUpdater, ensureStarted: @escaping () -> Void) {
        NSLog("SparkleBridge: Initializing channel com.breakmate/sparkle")
        self.channel = FlutterMethodChannel(
            name: "com.breakmate/sparkle",
            binaryMessenger: registrar.messenger
        )
        self.updater = updater
        self.ensureStarted = ensureStarted
        super.init()
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            NSLog("SparkleBridge: Received method call: \(call.method)")
            switch call.method {
            case "showUpdatePanel":
                guard let self = self else { result(nil); return }
                let args = call.arguments as? [String: Any]
                self.showUpdatePanel(theme: args?["theme"] as? [String: Any] ?? [:])
                result(nil)
            case "checkForUpdates":
                if let theme = (call.arguments as? [String: Any])?["theme"] as? [String: Any] {
                    self?.lastDialogTheme = theme
                }
                // This app action needs a fresh check with a result in our own UI.
                // An informational probe bypasses the background scheduler and
                // does not open Sparkle's separate update window.
                guard let self = self else {
                    result(FlutterError(code: "UPDATER_UNAVAILABLE", message: "The updater is unavailable.", details: nil))
                    return
                }
                // The updater starts a few seconds after launch and refuses new
                // checks while a background session runs, so start it now and
                // retry briefly before reporting failure.
                self.ensureStarted()
                self.startInformationalCheck(attemptsLeft: 20, result: result)
            case "startUpdate":
                NSLog("SparkleBridge: Triggering checkForUpdates (User-facing)")
                self?.ensureStarted()
                // Standard Sparkle user-facing update check and installation flow
                self?.startVisibleUpdate()
                result(nil)
            default:
                NSLog("SparkleBridge: Method not implemented: \(call.method)")
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func startInformationalCheck(attemptsLeft: Int, result: @escaping FlutterResult) {
        if updater.canCheckForUpdates {
            NSLog("SparkleBridge: Triggering checkForUpdateInformation")
            updater.checkForUpdateInformation()
            result(nil)
        } else if attemptsLeft > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startInformationalCheck(attemptsLeft: attemptsLeft - 1, result: result)
            }
        } else {
            result(FlutterError(code: "UPDATE_CHECK_UNAVAILABLE", message: "An update check cannot be started right now. Please try again in a moment.", details: nil))
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        finishPanel(version: item.displayVersionString)
        let notes = item.itemDescription ?? "No release notes available."
        let version = item.displayVersionString
        let args: [String: Any] = [
            "hasUpdate": true,
            "version": version,
            "notes": notes
        ]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onUpdateResult", arguments: args)
        }
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        finishPanel()
        let args: [String: Any] = [
            "hasUpdate": false,
            "version": "",
            "notes": ""
        ]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onUpdateResult", arguments: args)
        }
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nativeError = error as NSError
        if nativeError.domain == SUSparkleErrorDomain && nativeError.code == 1001 {
            finishPanel()
        } else {
            finishPanel(error: error.localizedDescription)
        }
        let args: [String: Any] = [
            "hasUpdate": false,
            "error": error.localizedDescription
        ]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onUpdateError", arguments: args)
        }
    }
}
