import Cocoa
import FlutterMacOS
import EventKit

/// Dedicated bridge for all Calendar / EventKit operations.
class CalendarBridge {

    // MARK: - Shared event store (replaced after each grant)

    /// The store used for fetching events. Replaced with a fresh instance
    /// every time the user grants access so it immediately picks up the new
    /// authorization without needing an app restart.
    private var eventStore = EKEventStore()

    /// Retains the EKEventStore during an active permission request.
    private var activeRequestStore: EKEventStore?

    // MARK: - Permission status helpers

    /// Returns the current TCC authorization status as a simple Bool.
    private var isCurrentlyAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    // MARK: - Public API (called from MainFlutterWindow's method-channel handler)

    /// Checks whether calendar access has already been granted.
    func hasCalendarPermissions(result: @escaping FlutterResult) {
        result(isCurrentlyAuthorized)
    }

    /// Gets the detailed calendar permission status.
    func getCalendarPermissionStatus(result: @escaping FlutterResult) {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            result("notDetermined")
        case .restricted:
            result("restricted")
        case .denied:
            result("denied")
        case .fullAccess:
            result("granted")
        case .writeOnly:
            result("denied") // Write-only is not enough for our reading needs
        case .authorized:
            result("granted")
        @unknown default:
            result("denied")
        }
    }

    /// Requests full calendar access from the OS.
    func requestCalendarPermissions(result: @escaping FlutterResult) {
        let status = EKEventStore.authorizationStatus(for: .event)
        NSLog("[BreakMate][Calendar] requestCalendarPermissions — raw status: \(status.rawValue)")

        if status == .denied || status == .restricted {
            NSLog("[BreakMate][Calendar] Denied/Restricted — returning false (user must open System Settings).")
            result(false)
            return
        }

        if isCurrentlyAuthorized {
            NSLog("[BreakMate][Calendar] Already authorized — returning true without prompting.")
            result(true)
            return
        }

        let requestStore = EKEventStore()
        self.activeRequestStore = requestStore

        if #available(macOS 14.0, *) {
            NSLog("[BreakMate][Calendar] Calling requestFullAccessToEvents (macOS 14+) …")
            requestStore.requestFullAccessToEvents { [weak self] granted, error in
                NSLog("[BreakMate][Calendar] requestFullAccessToEvents → granted=\(granted), error=\(error?.localizedDescription ?? "none")")
                DispatchQueue.main.async {
                    if granted {
                        self?.eventStore = EKEventStore()
                        NSLog("[BreakMate][Calendar] EKEventStore refreshed after grant.")
                    }
                    self?.activeRequestStore = nil
                    result(granted)
                }
            }
        } else {
            NSLog("[BreakMate][Calendar] Calling requestAccess (legacy) …")
            requestStore.requestAccess(to: .event) { [weak self] granted, error in
                NSLog("[BreakMate][Calendar] requestAccess → granted=\(granted), error=\(error?.localizedDescription ?? "none")")
                DispatchQueue.main.async {
                    if granted {
                        self?.eventStore = EKEventStore()
                        NSLog("[BreakMate][Calendar] EKEventStore refreshed after grant.")
                    }
                    self?.activeRequestStore = nil
                    result(granted)
                }
            }
        }
    }

    /// Opens the Calendar privacy pane in System Settings (macOS 13+) or System Preferences (macOS 12 and earlier).
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

    /// Fetches all available calendars.
    func getCalendars(result: @escaping FlutterResult) {
        guard isCurrentlyAuthorized else {
            result([])
            return
        }

        let calendars = eventStore.calendars(for: .event)
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
    func getEvents(startMs: Double, endMs: Double, calendarIds: [String]?, result: @escaping FlutterResult) {
        guard isCurrentlyAuthorized else {
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

            var calendars: [EKCalendar]? = nil
            if let ids = calendarIds {
                calendars = self.eventStore.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
            }

            let predicate = self.eventStore.predicateForEvents(
                withStart: start,
                end: end,
                calendars: calendars
            )
            let events = self.eventStore.events(matching: predicate)

            let mapped: [[String: Any]] = events.map { event in
                [
                    "id": event.eventIdentifier ?? "",
                    "calendarId": event.calendar?.calendarIdentifier ?? "",
                    "title": event.title ?? "No Title",
                    "notes": event.notes ?? "",
                    "start": Int(event.startDate.timeIntervalSince1970 * 1000),
                    "end": Int(event.endDate.timeIntervalSince1970 * 1000),
                    "allDay": event.isAllDay
                ]
            }

            DispatchQueue.main.async {
                result(mapped)
            }
        }
    }

    /// Fetches upcoming calendar events within the next `windowMinutes` minutes.
    func getUpcomingCalendarEvents(windowMinutes: Int, result: @escaping FlutterResult) {
        guard isCurrentlyAuthorized else {
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

            let predicate = self.eventStore.predicateForEvents(
                withStart: start,
                end: end,
                calendars: nil
            )
            let events = self.eventStore.events(matching: predicate)

            let mapped: [[String: Any]] = events.map { event in
                [
                    "id": event.eventIdentifier ?? "",
                    "calendarId": event.calendar?.calendarIdentifier ?? "",
                    "title": event.title ?? "No Title",
                    "notes": event.notes ?? "",
                    "start": Int(event.startDate.timeIntervalSince1970 * 1000),
                    "end": Int(event.endDate.timeIntervalSince1970 * 1000),
                    "allDay": event.isAllDay
                ]
            }

            DispatchQueue.main.async {
                result(mapped)
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
