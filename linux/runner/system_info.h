#ifndef RUNNER_SYSTEM_INFO_H_
#define RUNNER_SYSTEM_INFO_H_

#include <gtk/gtk.h>

#include <string>
#include <vector>

// Read-only queries about the desktop session. Window-level queries need an X11
// (or XWayland-visible) session; on pure Wayland there is no protocol for a
// client to ask about other applications' windows, so they report "unknown".
namespace bm {
namespace sys {

struct ActiveWindow {
  bool ok = false;
  std::string wm_class;    // lower-cased WM_CLASS class, e.g. "firefox"
  std::string exe_name;    // basename of /proc/<pid>/exe
  std::string exe_path;
  std::string title;
};

struct WindowRect {
  unsigned long id = 0;
  std::string wm_class;
  std::string title;
  double x = 0, y = 0, width = 0, height = 0;
  bool minimized = false;
};

struct DisplayRect {
  std::string id;
  bool primary = false;
  double x = 0, y = 0, width = 0, height = 0;
  double work_x = 0, work_y = 0, work_width = 0, work_height = 0;
  double scale = 1.0;
  double refresh_hz = 60.0;
};

bool IsX11();

ActiveWindow GetActiveWindow();
std::vector<WindowRect> GetVisibleWindows();

// Seconds since the last keyboard/mouse input; 0 when it cannot be determined.
double GetIdleSeconds();

bool GetCursorPosition(double* x, double* y);
std::vector<DisplayRect> GetDisplays();

// "dark" or "light".
std::string GetAppearance();

// True if |wm_class| / |exe_name| belongs to a known meeting application.
bool IsMeetingApp(const std::string& wm_class, const std::string& exe_name);

// Capture streams / camera devices in use by other processes.
bool IsMicrophoneInUse();
bool IsCameraInUse();

// Another application is keeping the display awake (video playback).
bool IsVideoPlaying();

// PNG bytes for an application icon, empty if none could be resolved.
std::vector<unsigned char> GetAppIconPng(const std::string& wm_class,
                                         const std::string& exe_name);

// Substring used to recognise our own inhibitors.
extern const char kInhibitReason[];

}  // namespace sys
}  // namespace bm

#endif  // RUNNER_SYSTEM_INFO_H_
