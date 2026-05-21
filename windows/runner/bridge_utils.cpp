#include "bridge_utils.h"
#include <psapi.h>
#include <iostream>
#include <algorithm>

namespace bridge_utils {

bool IsFocusModeActive() {
    QUERY_USER_NOTIFICATION_STATE state;
    if (SHQueryUserNotificationState(&state) == S_OK) {
        // QUNS_NOT_PRESENT: The user is not present.
        // QUNS_BUSY: The user is busy (e.g. running a full-screen app, or DND is on).
        // QUNS_RUNNING_D3D_FULL_SCREEN: A Direct3D application is running in full-screen mode.
        // QUNS_PRESENTATION_MODE: The user is in presentation mode.
        // QUNS_ACCEPTS_NOTIFICATIONS: Notifications are accepted (Normal).
        // QUNS_QUIET_TIME: Focus Assist / Quiet hours is active.
        return state != QUNS_ACCEPTS_NOTIFICATIONS;
    }
    return false;
}

bool IsMeetingActive(std::string& out_bundle_id) {
    HWND foreground = GetForegroundWindow();
    if (!foreground) return false;

    DWORD process_id;
    GetWindowThreadProcessId(foreground, &process_id);

    HANDLE process = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, process_id);
    if (!process) return false;

    TCHAR process_name[MAX_PATH];
    if (GetModuleFileNameEx(process, NULL, process_name, MAX_PATH)) {
        std::wstring ws(process_name);
        std::string name;
        name.reserve(ws.length());
        for (wchar_t wc : ws) {
            name += static_cast<char>(wc);
        }
        
        // Convert to lowercase for comparison
        std::string lower_name = name;
        std::transform(lower_name.begin(), lower_name.end(), lower_name.begin(),
                       [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

        const std::vector<std::string> known_meeting_apps = {
            "zoom.exe",
            "teams.exe",
            "slack.exe",
            "webex.exe",
            "discord.exe",
            "meet.exe"
        };

        for (const auto& app : known_meeting_apps) {
            if (lower_name.find(app) != std::string::npos) {
                out_bundle_id = app;
                CloseHandle(process);
                return true;
            }
        }
    }

    CloseHandle(process);
    return false;
}

double GetIdleTime() {
    LASTINPUTINFO lii;
    lii.cbSize = sizeof(LASTINPUTINFO);
    if (GetLastInputInfo(&lii)) {
        return (GetTickCount() - lii.dwTime) / 1000.0;
    }
    return 0.0;
}

} // namespace bridge_utils
