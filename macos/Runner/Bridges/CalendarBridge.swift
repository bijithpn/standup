import Cocoa
import FlutterMacOS
import EventKit

// MARK: - Authorization State Model

/// Represents the simplified EventKit authorization status.
enum CalendarAccessState: String {
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case fullAccess
}

/// Dedicated bridge for all Calendar / EventKit operations.
class CalendarBridge {

    // MARK: - Properties & Thread Safety

    /// Recreated EKEventStore instance for querying calendars/events.
    private var _eventStore = EKEventStore()

    /// Retained EKEventStore during active permission requests.
    private var _activeRequestStore: EKEventStore?

    /// Thread lock to synchronize access to the EventStore properties.
    private let lock = NSLock()

    // MARK: - Thread-Safe Getters & Setters

    /// Thread-safe access to the primary EventStore.
    private var eventStore: EKEventStore {
        lock.lock()
        defer { lock.unlock() }
        return _eventStore
    }

    /// Thread-safe access to the active request EventStore.
    private var activeRequestStore: EKEventStore? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _activeRequestStore
        }
        set {
            lock.lock()
            _activeRequestStore = newValue
            lock.unlock()
        }
    }

    /// Maps the raw EKAuthorizationStatus integer to a CalendarAccessState.
    /// Uses rawValue switching so this compiles on every macOS SDK without
    /// availability guards around `.fullAccess` / `.writeOnly`.
    ///
    /// Raw value map (stable across SDKs):
    ///   0 = .notDetermined
    ///   1 = .restricted
    ///   2 = .denied
    ///   3 = .authorized (pre-macOS 14) / .fullAccess (macOS 14+)
    ///   4 = .writeOnly  (macOS 14+)
    private func currentAccessState() -> CalendarAccessState {
        let status = EKEventStore.authorizationStatus(for: .event)
        NSLog("[BreakMate Calendar] currentAccessState raw: \(status.rawValue)")
        
        switch status.rawValue {
        case 0: return .notDetermined
        case 1: return .restricted
        case 2: return .denied
        case 3: return .fullAccess   // .authorized on ≤macOS 13, .fullAccess on macOS 14+
        case 4: return .writeOnly
        default: return .denied
        }
    }

    /// True when the app currently has read access to calendar events.
    private var hasReadAccess: Bool {
        return currentAccessState() == .fullAccess
    }

    // MARK: - Store Lifecycle Management

    /// Recreates the EKEventStore instance to prevent cached stale authorization state.
    private func refreshStore() {
        lock.lock()
        _eventStore = EKEventStore()
        lock.unlock()
        logAuthorizationStatus("refreshStore")
    }

    // MARK: - Diagnostics & Logging

    /// Logs detailed authorization status and metrics.
    /// - Parameter source: Describes the context of the logging invocation.
    private func logAuthorizationStatus(_ source: String) {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let state = currentAccessState()
        let statusRaw = EKEventStore.authorizationStatus(for: .event).rawValue

        let currentStore = self.eventStore
        
        // We try to access calendars to see if it actually works, not just what the status says.
        var canFetchCalendars = false
        var calendarCount = 0
        
        if hasReadAccess {
            let calendars = currentStore.calendars(for: .event)
            calendarCount = calendars.count
            canFetchCalendars = true
        }

        let logString = """
        [BreakMate Calendar]
        source=\(source)
        bundle=\(bundleId)
        status=\(statusRaw)
        state=\(state.rawValue)
        canFetch=\(canFetchCalendars)
        count=\(calendarCount)
        """
        NSLog("%@", logString)
    }

    // MARK: - Public API (Flutter Method Channels)

    /// Exposes detailed authorization diagnostics for Flutter.
    /// - Parameter result: Flutter method channel result callback.
    func debugCalendarState(result: @escaping FlutterResult) {
        let statusRaw = EKEventStore.authorizationStatus(for: .event).rawValue
        let diagnostics: [String: Any?] = [
            "bundleId": Bundle.main.bundleIdentifier,
            "authorizationStatus": statusRaw,
            "hasReadAccess": hasReadAccess,
            "canFetch": hasReadAccess && !eventStore.calendars(for: .event).isEmpty
        ]
        NSLog("[BreakMate Calendar] debugCalendarState returned: \(diagnostics)")
        result(diagnostics)
    }

    /// Checks whether calendar access has already been granted.
    /// - Parameter result: Flutter method channel result callback.
    func hasCalendarPermissions(result: @escaping FlutterResult) {
        refreshStore()
        logAuthorizationStatus("hasCalendarPermissions")
        result(hasReadAccess)
    }

    /// Gets the detailed calendar permission status.
    /// - Parameter result: Flutter method channel result callback.
    func getCalendarPermissionStatus(result: @escaping FlutterResult) {
        let state = currentAccessState()
        logAuthorizationStatus("getCalendarPermissionStatus")
        switch state {
        case .notDetermined: result("notDetermined")
        case .restricted:    result("restricted")
        case .denied:        result("denied")
        case .fullAccess:    result("granted")
        case .writeOnly:     result("denied")
        }
    }

    // MARK: - Permission Request

    /// Requests full calendar access from the OS.
    ///
    /// Root-cause fix (macOS 14 TCC race condition):
    /// `requestFullAccessToEvents` can fire its completion callback with `granted=false`
    /// even when the user clicked "Allow", because the TCC database has not yet
    /// committed the authorization by the time the callback runs.
    /// Conversely, if it returns `granted=true`, we should trust it immediately.
    ///
    /// - Parameter result: Flutter method channel result callback.
    func requestCalendarPermissions(result: @escaping FlutterResult) {
        NSLog("[BreakMate Calendar] requestCalendarPermissions ENTERED")
        logAuthorizationStatus("request-start")

        let state = currentAccessState()
        if state == .fullAccess {
            logAuthorizationStatus("request-already-authorized")
            result(true)
            return
        }

        // We create a fresh store for the request.
        let requestStore = EKEventStore()
        self.activeRequestStore = requestStore

        if #available(macOS 14.0, *) {
            logAuthorizationStatus("request-prompt-macos14")
            NSLog("[BreakMate Calendar] Calling requestFullAccessToEvents (macOS 14+)")

            requestStore.requestFullAccessToEvents { [weak self] grantedParam, error in
                let errorDesc = error?.localizedDescription ?? "none"
                NSLog("[BreakMate Calendar] requestFullAccessToEvents callback: grantedParam=\(grantedParam), error=\(errorDesc)")
                
                let immediateStatus = EKEventStore.authorizationStatus(for: .event)
                NSLog("[BreakMate Calendar] Immediate status after callback: \(immediateStatus.rawValue)")

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { 
                        result(false)
                        return 
                    }
                    
                    // We don't return immediately even if grantedParam is true, because 
                    // subsequent calls to getCalendarPermissionStatus (which happen 
                    // immediately in Flutter) might still see the old state.
                    // We always pass through resolveGrantedWithRetry to be safe.
                    let initialWait = grantedParam ? 0.0 : 0.1
                    NSLog("[BreakMate Calendar] Callback result handled. grantedParam=\(grantedParam). Waiting \(initialWait)s then polling status...")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + initialWait) { [weak self] in
                        guard let self = self else { return }
                        self.resolveGrantedWithRetry(attempt: 0, maxAttempts: 12, result: result)
                    }
                }
            }
        } else {
            logAuthorizationStatus("request-prompt-legacy")
            NSLog("[BreakMate Calendar] Calling requestAccess (legacy, pre-macOS 14)")

            requestStore.requestAccess(to: .event) { [weak self] grantedParam, error in
                let errorDesc = error?.localizedDescription ?? "none"
                NSLog("[BreakMate Calendar] requestAccess callback: grantedParam=\(grantedParam), error=\(errorDesc)")

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        result(false)
                        return
                    }
                    
                    let initialWait = grantedParam ? 0.0 : 0.1
                    DispatchQueue.main.asyncAfter(deadline: .now() + initialWait) { [weak self] in
                        guard let self = self else { return }
                        self.resolveGrantedWithRetry(attempt: 0, maxAttempts: 8, result: result)
                    }
                }
            }
        }
    }

    /// Polls the event store authorization status recursively to outlast the macOS TCC write latency.
    /// This is necessary because macOS 14+ TCC helper processes commit permission updates asynchronously,
    /// causing immediate checks following authorization callbacks to return stale results.
    private func resolveGrantedWithRetry(attempt: Int, maxAttempts: Int, result: @escaping FlutterResult) {
        let status = EKEventStore.authorizationStatus(for: .event)
        let rawValue = status.rawValue
        
        // rawValue 3 = .authorized (≤macOS 13) / .fullAccess (macOS 14+)
        let isGranted = (rawValue == 3)

        NSLog("[BreakMate Calendar] resolveGrantedWithRetry: attempt=\(attempt)/\(maxAttempts) rawValue=\(rawValue) isGranted=\(isGranted)")

        // If we have a definitive answer (anything other than notDetermined = 0), return.
        if rawValue != 0 {
            if isGranted {
                self.refreshStore()
                self.logAuthorizationStatus("request-granted-final")
            } else {
                if rawValue == 4 {
                    NSLog("[BreakMate Calendar] User granted WRITE-ONLY access. This is insufficient for reading events.")
                }
                self.logAuthorizationStatus("request-denied-final")
                self.showDeniedRecoveryAlert()
            }
            self.activeRequestStore = nil
            result(isGranted)
            return
        }
        
        // If we hit max attempts and it's still 0, return false.
        if attempt >= maxAttempts {
            NSLog("[BreakMate Calendar] resolveGrantedWithRetry hit max attempts. Returning false.")
            self.logAuthorizationStatus("request-timeout-final")
            self.showDeniedRecoveryAlert()
            self.activeRequestStore = nil
            result(false)
            return
        }

        // Still notDetermined — wait and retry.
        // Increase wait time slightly (250ms) to be safer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { result(false); return }
            self.resolveGrantedWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, result: result)
        }
    }

    private func showDeniedRecoveryAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Calendar Permission Denied"
            alert.informativeText = "BreakMate requires Calendar access to read upcoming meetings and adjust your break schedule accordingly. Would you like to open System Settings to enable it?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openCalendarSettings(result: { _ in })
            }
        }
    }

    // MARK: - Settings

    /// Opens the Calendar privacy pane in System Settings (macOS 13+) or System Preferences (macOS 12 and earlier).
    /// - Parameter result: Flutter method channel result callback.
    func openCalendarSettings(result: @escaping FlutterResult) {
        if #available(macOS 13.0, *) {
            let newUrl = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars")!
            if NSWorkspace.shared.open(newUrl) {
                result(true)
                return
            }
            let fallback13 = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")!
            if NSWorkspace.shared.open(fallback13) {
                result(true)
                return
            }
        }

        let legacyUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        NSWorkspace.shared.open(legacyUrl)
        result(true)
    }

    // MARK: - Calendar & Event Queries

    /// Fetches all available calendars.
    /// - Parameter result: Flutter method channel result callback.
    func getCalendars(result: @escaping FlutterResult) {
        refreshStore()

        let authorized = hasReadAccess
        NSLog("[BreakMate Calendar] getCalendars starting query. Authorized: \(authorized)")

        guard authorized else {
            result([])
            return
        }

        let currentStore = self.eventStore
        let calendars = currentStore.calendars(for: .event)
        NSLog("[BreakMate Calendar] getCalendars query returned \(calendars.count) calendars")

        let mapped: [[String: Any]] = calendars.map { calendar in
            [
                "id": calendar.calendarIdentifier,
                "name": calendar.title,
                "color": calendar.color.toHex(),
                "isReadOnly": !calendar.allowsContentModifications
            ]
        }
        result(mapped)
    }

    /// Fetches events within a specific range, optionally filtered by calendar IDs.
    /// - Parameters:
    ///   - startMs: Start date in milliseconds since epoch.
    ///   - endMs: End date in milliseconds since epoch.
    ///   - calendarIds: Optional list of calendar identifiers to filter by.
    ///   - result: Flutter method channel result callback.
    func getEvents(startMs: Double, endMs: Double, calendarIds: [String]?, result: @escaping FlutterResult) {
        refreshStore()

        let authorized = hasReadAccess
        NSLog("[BreakMate Calendar] getEvents starting query check. Authorized: \(authorized)")

        guard authorized else {
            result([])
            return
        }

        let start = Date(timeIntervalSince1970: startMs / 1000.0)
        let end = Date(timeIntervalSince1970: endMs / 1000.0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { result([]) }
                return
            }

            do {
                self.logAuthorizationStatus("getEvents-bg")
                NSLog("[BreakMate Calendar] getEvents background query starting from \(start) to \(end)...")

                let threadStore = EKEventStore()
                var calendars: [EKCalendar]? = nil
                if let ids = calendarIds {
                    calendars = threadStore.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
                }

                let predicate = threadStore.predicateForEvents(
                    withStart: start,
                    end: end,
                    calendars: calendars
                )
                let events = threadStore.events(matching: predicate)

                NSLog("[BreakMate Calendar] getEvents background query complete. Found \(events.count) events.")

                let mapped: [[String: Any]] = events.map { event in
                    [
                        "id": event.eventIdentifier ?? "",
                        "calendarId": event.calendar?.calendarIdentifier ?? "",
                        "title": event.title ?? "No Title",
                        "notes": event.notes ?? "",
                        "location": event.location ?? "",
                        "url": event.url?.absoluteString ?? "",
                        "start": Int(event.startDate.timeIntervalSince1970 * 1000),
                        "end": Int(event.endDate.timeIntervalSince1970 * 1000),
                        "allDay": event.isAllDay
                    ]
                }

                if false {
                    throw NSError(domain: "CalendarBridgeError", code: -1, userInfo: nil)
                }

                DispatchQueue.main.async {
                    result(mapped)
                }
            } catch {
                NSLog("[BreakMate Calendar] getEvents exception: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    result([])
                }
            }
        }
    }

    /// Fetches upcoming calendar events within the next `windowMinutes` minutes.
    /// - Parameters:
    ///   - windowMinutes: The number of minutes from now to query.
    ///   - result: Flutter method channel result callback.
    func getUpcomingCalendarEvents(windowMinutes: Int, result: @escaping FlutterResult) {
        refreshStore()

        let authorized = hasReadAccess
        NSLog("[BreakMate Calendar] getUpcomingCalendarEvents starting query check. Authorized: \(authorized)")

        guard authorized else {
            result([])
            return
        }

        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(windowMinutes * 60))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { result([]) }
                return
            }

            do {
                self.logAuthorizationStatus("getUpcomingCalendarEvents-bg")
                NSLog("[BreakMate Calendar] getUpcomingCalendarEvents background query starting for window \(windowMinutes) minutes...")

                let threadStore = EKEventStore()
                let predicate = threadStore.predicateForEvents(
                    withStart: start,
                    end: end,
                    calendars: nil
                )
                let events = threadStore.events(matching: predicate)

                NSLog("[BreakMate Calendar] getUpcomingCalendarEvents background query complete. Found \(events.count) events.")

                let mapped: [[String: Any]] = events.map { event in
                    [
                        "id": event.eventIdentifier ?? "",
                        "calendarId": event.calendar?.calendarIdentifier ?? "",
                        "title": event.title ?? "No Title",
                        "notes": event.notes ?? "",
                        "location": event.location ?? "",
                        "url": event.url?.absoluteString ?? "",
                        "start": Int(event.startDate.timeIntervalSince1970 * 1000),
                        "end": Int(event.endDate.timeIntervalSince1970 * 1000),
                        "allDay": event.isAllDay
                    ]
                }

                if false {
                    throw NSError(domain: "CalendarBridgeError", code: -1, userInfo: nil)
                }

                DispatchQueue.main.async {
                    result(mapped)
                }
            } catch {
                NSLog("[BreakMate Calendar] getUpcomingCalendarEvents exception: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    result([])
                }
            }
        }
    }
}

// MARK: - Color Extension Helper
extension NSColor {
    func toHex() -> String {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            return "#808080"
        }
        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
