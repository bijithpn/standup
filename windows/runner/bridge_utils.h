#ifndef RUNNER_BRIDGE_UTILS_H_
#define RUNNER_BRIDGE_UTILS_H_

#include <windows.h>
#include <shellapi.h>
#include <string>
#include <vector>

namespace bridge_utils {

// Checks if Windows "Focus Assist" or any full-screen app is running (DND equivalent)
bool IsFocusModeActive();

// Checks if any known meeting applications are currently frontmost
bool IsMeetingActive(std::string& out_bundle_id);

// Gets system idle time in seconds
double GetIdleTime();

} // namespace bridge_utils

#endif // RUNNER_BRIDGE_UTILS_H_
