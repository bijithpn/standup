#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <shellapi.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler.h>

#include "flutter/generated_plugin_registrant.h"
#include <flutter_acrylic/flutter_acrylic_plugin.h>
#include "calendar_bridge.h"
#include "bridge_utils.h"
#include "overlay_window_manager.h"
#include "companion_window_manager.h"
#include "ipc_bridge_manager.h"
#include "overlay_window_plugin.h"
#include "display_bridge.h"

// ... rest of stream handlers ...

struct WindowData {
  HWND hwnd;
  std::wstring title;
  std::wstring class_name;
  RECT rect;
  bool is_minimized;
};

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
  std::vector<WindowData>* windows = reinterpret_cast<std::vector<WindowData>*>(lParam);
  if (!IsWindowVisible(hwnd)) {
    return TRUE;
  }
  int title_length = GetWindowTextLengthW(hwnd);
  if (title_length == 0) {
    return TRUE;
  }
  LONG ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);
  if (ex_style & WS_EX_TOOLWINDOW) {
    return TRUE;
  }
  wchar_t title[256];
  GetWindowTextW(hwnd, title, 256);
  wchar_t class_name[256];
  GetClassNameW(hwnd, class_name, 256);
  RECT rect;
  GetWindowRect(hwnd, &rect);
  bool is_minimized = IsIconic(hwnd) != 0;
  windows->push_back({hwnd, std::wstring(title), std::wstring(class_name), rect, is_minimized});
  return TRUE;
}

HHOOK FlutterWindow::keyboard_hook_ = nullptr;
int FlutterWindow::keyboard_hook_ref_count_ = 0;
FlutterWindow* FlutterWindow::main_window_ = nullptr;
std::set<FlutterWindow*> FlutterWindow::active_windows_;

LRESULT CALLBACK FlutterWindow::LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode == HC_ACTION) {
    KBDLLHOOKSTRUCT* pKeyBoard = (KBDLLHOOKSTRUCT*)lParam;
    bool winDown = (GetAsyncKeyState(VK_LWIN) & 0x8000) || (GetAsyncKeyState(VK_RWIN) & 0x8000);
    bool ctrlDown = (GetAsyncKeyState(VK_LCONTROL) & 0x8000) || (GetAsyncKeyState(VK_RCONTROL) & 0x8000);
    
    // Block Win+Ctrl+Left/Right (Virtual Desktop Switch via 4-finger swipe)
    if (winDown && ctrlDown && (pKeyBoard->vkCode == VK_LEFT || pKeyBoard->vkCode == VK_RIGHT)) {
      return 1; // swallow
    }
    // Block Win+Tab (Task View via 3-finger swipe)
    if (winDown && pKeyBoard->vkCode == VK_TAB) {
      return 1; // swallow
    }
    // Forward Escape keydown to all active overlay engines so the break can be
    // dismissed even when the overlay window has no keyboard focus (SWP_NOACTIVATE).
    if (pKeyBoard->vkCode == VK_ESCAPE && wParam == WM_KEYDOWN) {
      OverlayWindowManager::GetInstance()->HandleEscapeKey();
    }
  }
  return CallNextHookEx(keyboard_hook_, nCode, wParam, lParam);
}

class FocusModeStreamHandler;
static FocusModeStreamHandler* g_focus_mode_handler = nullptr;

class MeetingDetectionStreamHandler;
static MeetingDetectionStreamHandler* g_meeting_detection_handler = nullptr;

class FocusModeStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  FocusModeStreamHandler() {}
  virtual ~FocusModeStreamHandler() {
    if (g_focus_mode_handler == this) {
      g_focus_mode_handler = nullptr;
    }
  }

  void SendUpdate(bool is_active) {
    if (event_sink_) {
      event_sink_->Success(flutter::EncodableValue(is_active));
    }
  }

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    event_sink_ = std::move(events);
    event_sink_->Success(flutter::EncodableValue(bridge_utils::IsFocusModeActive()));
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override {
    event_sink_ = nullptr;
    return nullptr;
  }

 private:
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};

// Stream handler for Meeting Detection
class MeetingDetectionStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  MeetingDetectionStreamHandler() {}
  virtual ~MeetingDetectionStreamHandler() {
    if (g_meeting_detection_handler == this) {
      g_meeting_detection_handler = nullptr;
    }
  }

  void SendUpdate(bool is_active, const std::string& bundle_id) {
    if (event_sink_) {
      flutter::EncodableMap data;
      data[flutter::EncodableValue("isMeetingAppFrontmost")] = flutter::EncodableValue(is_active);
      data[flutter::EncodableValue("bundleId")] = flutter::EncodableValue(bundle_id);
      event_sink_->Success(flutter::EncodableValue(data));
    }
  }

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    event_sink_ = std::move(events);
    std::string bundle_id;
    bool is_active = bridge_utils::IsMeetingActive(bundle_id);
    flutter::EncodableMap data;
    data[flutter::EncodableValue("isMeetingAppFrontmost")] = flutter::EncodableValue(is_active);
    data[flutter::EncodableValue("bundleId")] = flutter::EncodableValue(bundle_id);
    event_sink_->Success(flutter::EncodableValue(data));
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override {
    event_sink_ = nullptr;
    return nullptr;
  }

 private:
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};

static DisplayStreamHandler* g_display_stream_handler = nullptr;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project), ignore_mouse_events_(false) {
  active_windows_.insert(this);
}

FlutterWindow::~FlutterWindow() {
  active_windows_.erase(this);
}

bool FlutterWindow::Show() {
  BOOL res = FALSE;
  if (is_overlay_) {
    // Determine the final window bounds from the stored overlay rect or
    // fall back to querying the current monitor. Position must be applied
    // before ShowWindow so the Flutter compositor initialises at the
    // correct viewport size on the very first frame.
    int left = 0, top = 0, width = 0, height = 0;
    if (overlay_rect_.right > overlay_rect_.left && overlay_rect_.bottom > overlay_rect_.top) {
      left   = overlay_rect_.left;
      top    = overlay_rect_.top;
      width  = overlay_rect_.right  - overlay_rect_.left;
      height = overlay_rect_.bottom - overlay_rect_.top;
    } else {
      HMONITOR monitor = MonitorFromWindow(GetHandle(), MONITOR_DEFAULTTONEAREST);
      MONITORINFO monitorInfo = {};
      monitorInfo.cbSize = sizeof(MONITORINFO);
      GetMonitorInfo(monitor, &monitorInfo);
      left   = monitorInfo.rcMonitor.left;
      top    = monitorInfo.rcMonitor.top;
      width  = monitorInfo.rcMonitor.right  - monitorInfo.rcMonitor.left;
      height = monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top;
    }

    printf("[FlutterWindow::Show] HWND: %p, overlay_rect_: {%ld, %ld, %ld, %ld}, left: %d, top: %d, width: %d, height: %d\n",
           (void*)GetHandle(), overlay_rect_.left, overlay_rect_.top, overlay_rect_.right, overlay_rect_.bottom, left, top, width, height);
    fflush(stdout);

    // Apply full-screen bounds and force a frame-change so the NC area
    // (none for WS_POPUP) and z-order are re-evaluated before the window
    // becomes visible.
    UINT swp_flags = SWP_FRAMECHANGED;
    if (ignore_mouse_events_) {
      swp_flags |= SWP_NOACTIVATE;
    }
    SetWindowPos(GetHandle(), HWND_TOPMOST, left, top, width, height, swp_flags);

    // Now make the window visible. SW_SHOWNOACTIVATE avoids stealing focus
    // from other windows when the overlay is click-through.
    UINT show_flag = ignore_mouse_events_ ? SW_SHOWNOACTIVATE : SW_SHOW;
    res = ShowWindow(GetHandle(), show_flag);

    if (!ignore_mouse_events_) {
      SetForegroundWindow(GetHandle());
    }
  } else {
    res = Win32Window::Show();
  }

  // Force the child Flutter view to update its layout size and DPR when the window is shown.
  // This prevents layout squishing/stretching on secondary displays with different DPI scales.
  if (flutter_controller_ && flutter_controller_->view()) {
    HWND child_hwnd = flutter_controller_->view()->GetNativeWindow();
    if (child_hwnd) {
      RECT rect = GetClientArea();
      ::MoveWindow(child_hwnd, rect.left, rect.top, rect.right - rect.left - 1, rect.bottom - rect.top, TRUE);
      ::MoveWindow(child_hwnd, rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top, TRUE);
    }
  }

  return res;
}

bool FlutterWindow::OnCreate() {
  calendar_bridge_ = std::make_unique<CalendarBridge>();
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  if (is_companion_ || is_overlay_ || is_pip_) {
    // Only register plugins needed by secondary windows (avoid window_manager/objectbox/sentry crashes)
    FlutterAcrylicPluginRegisterWithRegistrar(
        flutter_controller_->engine()->GetRegistrarForPlugin("FlutterAcrylicPlugin"));
    RegisterOverlayWindowPlugin(flutter_controller_->engine());
  } else {
    // Main window: register all plugins
    RegisterPlugins(flutter_controller_->engine());
    RegisterOverlayWindowPlugin(flutter_controller_->engine());
  }

  // Register this engine with the IPC bridge so com.breakmate/ipc works
  IpcBridgeManager::GetInstance()->RegisterEngine(flutter_controller_->engine());

  if (is_companion_) {
    // Companion window: only set up channels the companion widget needs.
    SetupBridge();
    if (is_pip_) {
      SetupPiPBridge();
      SetupWindowBridge();  // PiP needs startDrag / setNonActivating
    } else {
      SetupCompanionBridge();
    }
    SetupOverlayBridge();
    DisplayStreamHandler* dummy_handler = nullptr;
    RegisterDisplayBridge(flutter_controller_->engine(), &dummy_handler);
  } else if (is_overlay_) {
    // Overlay window: only set up overlay-specific channels.
    SetupOverlayBridge();
  } else {
    // Main application window: full channel + event setup
    main_window_ = this;
    SetupBridge();
    SetupEventChannels();
    SetupWindowBridge();
    SetupOverlayBridge();
    RegisterDisplayBridge(flutter_controller_->engine(), &g_display_stream_handler);
    // Set up a timer to poll for focus/meeting updates (every 2 seconds)
    SetTimer(GetHandle(), 1, 2000, NULL);
  }
  
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    if (active_windows_.find(this) != active_windows_.end()) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}


void FlutterWindow::SetupWindowBridge() {
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate/window",
      &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const std::string& method_name = call.method_name();
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

        if (method_name == "setWindowLevel") {
          if (args) {
            auto level_it = args->find(flutter::EncodableValue("level"));
            if (level_it != args->end()) {
              std::string level = std::get<std::string>(level_it->second);
              HWND hwnd = GetHandle();
              if (level == "floating" || level == "screenSaver") {
                SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
              } else {
                SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
              }
            }
          }
          result->Success();
        }
        else if (method_name == "setWindowPosition") {
          if (args) {
            auto x_it = args->find(flutter::EncodableValue("x"));
            auto y_it = args->find(flutter::EncodableValue("y"));
            if (x_it != args->end() && y_it != args->end()) {
                double x = std::get<double>(x_it->second);
                double y = std::get<double>(y_it->second);
                HWND hwnd = GetHandle();
                double scale = static_cast<double>(GetDpiForWindow(hwnd)) / 96.0;
                int px = static_cast<int>(x * scale);
                int py = static_cast<int>(y * scale);
                
                // Get the actual monitor at the physical target point to get its correct DPI scale
                HMONITOR monitor = MonitorFromPoint({px, py}, MONITOR_DEFAULTTONEAREST);
                UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
                double target_scale = static_cast<double>(dpi) / 96.0;
                if (target_scale != scale) {
                  px = static_cast<int>(x * target_scale);
                  py = static_cast<int>(y * target_scale);
                }
                SetWindowPos(hwnd, NULL, px, py, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
            }
          }
          result->Success();
        }
        else if (method_name == "setWindowSize") {
          if (args) {
            auto width_it = args->find(flutter::EncodableValue("width"));
            auto height_it = args->find(flutter::EncodableValue("height"));
            if (width_it != args->end() && height_it != args->end()) {
                double w = 0.0;
                if (std::holds_alternative<double>(width_it->second)) {
                  w = std::get<double>(width_it->second);
                } else if (std::holds_alternative<int>(width_it->second)) {
                  w = static_cast<double>(std::get<int>(width_it->second));
                } else if (std::holds_alternative<int64_t>(width_it->second)) {
                  w = static_cast<double>(std::get<int64_t>(width_it->second));
                }

                double h = 0.0;
                if (std::holds_alternative<double>(height_it->second)) {
                  h = std::get<double>(height_it->second);
                } else if (std::holds_alternative<int>(height_it->second)) {
                  h = static_cast<double>(std::get<int>(height_it->second));
                } else if (std::holds_alternative<int64_t>(height_it->second)) {
                  h = static_cast<double>(std::get<int64_t>(height_it->second));
                }

                if (w > 0 && h > 0) {
                  HWND hwnd = GetHandle();
                  double scale = static_cast<double>(GetDpiForWindow(hwnd)) / 96.0;
                  int pw = static_cast<int>(w * scale);
                  int ph = static_cast<int>(h * scale);
                  SetWindowPos(hwnd, NULL, 0, 0, pw, ph, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
                }
            }
          }
          result->Success();
        }
        else if (method_name == "getWindowPosition") {
          HWND hwnd = GetHandle();
          RECT rect;
          GetWindowRect(hwnd, &rect);
          double scale = static_cast<double>(GetDpiForWindow(hwnd)) / 96.0;
          flutter::EncodableMap pos;
          pos[flutter::EncodableValue("x")] = flutter::EncodableValue(static_cast<double>(rect.left) / scale);
          pos[flutter::EncodableValue("y")] = flutter::EncodableValue(static_cast<double>(rect.top) / scale);
          pos[flutter::EncodableValue("width")] = flutter::EncodableValue(static_cast<double>(rect.right - rect.left) / scale);
          pos[flutter::EncodableValue("height")] = flutter::EncodableValue(static_cast<double>(rect.bottom - rect.top) / scale);
          result->Success(flutter::EncodableValue(pos));
        }
        else if (method_name == "setWindowOpacity") {
          if (args) {
            auto opacity_it = args->find(flutter::EncodableValue("opacity"));
            if (opacity_it != args->end()) {
                SetWindowTransparency(std::get<double>(opacity_it->second));
            }
          }
          result->Success();
        }
        else if (method_name == "setIgnoresMouseEvents") {
          if (args) {
            auto ignore_it = args->find(flutter::EncodableValue("ignore"));
            if (ignore_it != args->end()) {
                SetIgnoreMouseEvents(std::get<bool>(ignore_it->second));
            }
          }
          result->Success();
        }
        else if (method_name == "showWindow") {
          ShowWindow(GetHandle(), SW_SHOW);
          result->Success();
        }
        else if (method_name == "hideWindow") {
          ShowWindow(GetHandle(), SW_HIDE);
          result->Success();
        }
        else if (method_name == "orderFrontRegardless") {
          SetForegroundWindow(GetHandle());
          result->Success();
        }
        else if (method_name == "setHasShadow") {
          // On Windows, shadow is part of the window style.
          // For now, just success.
          result->Success();
        }
        else if (method_name == "setAcceptsMouseMovedEvents") {
          // Windows always accepts mouse moved events if the window is visible
          result->Success();
        }
        else if (method_name == "setWindowStyle") {
          // Could implement borderless/titled style changes here
          result->Success();
        }
        else if (method_name == "startDrag") {
          // Release mouse capture and let the OS handle window dragging via
          // the caption hit-test — the standard mechanism for borderless windows.
          HWND hwnd = GetHandle();
          ReleaseCapture();
          SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
        }
        else if (method_name == "setNonActivating") {
          // Toggle WS_EX_NOACTIVATE so the PiP window doesn't steal focus
          // when the drag handle is clicked.
          bool non_activating = true;
          if (args) {
            auto it = args->find(flutter::EncodableValue("nonActivating"));
            if (it != args->end() && std::holds_alternative<bool>(it->second)) {
              non_activating = std::get<bool>(it->second);
            }
          }
          HWND hwnd = GetHandle();
          LONG ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);
          if (non_activating) {
            ex_style |= WS_EX_NOACTIVATE;
          } else {
            ex_style &= ~WS_EX_NOACTIVATE;
          }
          SetWindowLong(hwnd, GWL_EXSTYLE, ex_style);
          result->Success();
        }
        else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::SetupPiPBridge() {
  auto pip_data_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate.desktop/pip_data",
      &flutter::StandardMethodCodec::GetInstance());

  flutter::EncodableMap settings = initial_settings_;
  pip_data_channel->SetMethodCallHandler(
      [settings](const auto& call, auto result) {
        if (call.method_name() == "getInitialSettings") {
          result->Success(flutter::EncodableValue(settings));
        } else {
          result->NotImplemented();
        }
      });

  // Keep the channel alive by transferring ownership to the instance var.
  // We reuse companion_channel_ slot to avoid adding new fields to the header.
  companion_channel_ = std::move(pip_data_channel);
}

void FlutterWindow::SetupCompanionBridge() {
  companion_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate.desktop/companion_data",
      &flutter::StandardMethodCodec::GetInstance());

  companion_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const std::string& method_name = call.method_name();

        if (method_name == "getInitialSettings") {
          result->Success(flutter::EncodableValue(initial_settings_));
        }
        else if (method_name == "syncCompanionSettings") {
          // Handled via InvokeMethod from native
          result->Success();
        }
        else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::SetupEventChannels() {
  auto focus_handler = std::make_unique<FocusModeStreamHandler>();
  g_focus_mode_handler = focus_handler.get();
  focus_mode_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate/focus_mode",
      &flutter::StandardMethodCodec::GetInstance());
  focus_mode_channel_->SetStreamHandler(std::move(focus_handler));

  auto meeting_handler = std::make_unique<MeetingDetectionStreamHandler>();
  g_meeting_detection_handler = meeting_handler.get();
  meeting_detection_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate/meeting_detection",
      &flutter::StandardMethodCodec::GetInstance());
  meeting_detection_channel_->SetStreamHandler(std::move(meeting_handler));
}

void FlutterWindow::SetupBridge() {
  bridge_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate.desktop/bridge",
      &flutter::StandardMethodCodec::GetInstance());

  bridge_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method_name = call.method_name();

        if (is_companion_ &&
            method_name != "getCursorPosition" &&
            method_name != "getVisibleWindows" &&
            method_name != "showConstraintWindow" &&
            method_name != "hideConstraintWindow" &&
            method_name != "hidePipWindow") {
          result->NotImplemented();
          return;
        }

        if (method_name == "getIdleTime") {
          result->Success(flutter::EncodableValue(bridge_utils::GetIdleTime()));
        }
        else if (method_name == "getCursorPosition") {
          POINT pt;
          if (GetCursorPos(&pt)) {
            HMONITOR monitor = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
            UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
            double scale = static_cast<double>(dpi) / 96.0;

            flutter::EncodableMap pos;
            pos[flutter::EncodableValue("x")] = flutter::EncodableValue(static_cast<double>(pt.x) / scale);
            pos[flutter::EncodableValue("y")] = flutter::EncodableValue(static_cast<double>(pt.y) / scale);
            result->Success(flutter::EncodableValue(pos));
          } else {
            result->Error("CURSOR_ERROR", "Failed to get cursor position");
          }
        }
        else if (method_name == "getVisibleWindows") {
          std::vector<WindowData> window_list;
          EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(&window_list));

          flutter::EncodableList encodable_list;
          for (const auto& w : window_list) {
            flutter::EncodableMap map;
            map[flutter::EncodableValue("windowId")] = flutter::EncodableValue(reinterpret_cast<int64_t>(w.hwnd));
            
            // Convert title to UTF-8
            int size_needed = WideCharToMultiByte(CP_UTF8, 0, w.title.c_str(), -1, NULL, 0, NULL, NULL);
            std::string title_utf8(size_needed > 0 ? size_needed - 1 : 0, 0);
            if (size_needed > 0) {
              WideCharToMultiByte(CP_UTF8, 0, w.title.c_str(), -1, &title_utf8[0], size_needed, NULL, NULL);
            }

            // Convert class name to UTF-8
            size_needed = WideCharToMultiByte(CP_UTF8, 0, w.class_name.c_str(), -1, NULL, 0, NULL, NULL);
            std::string class_utf8(size_needed > 0 ? size_needed - 1 : 0, 0);
            if (size_needed > 0) {
              WideCharToMultiByte(CP_UTF8, 0, w.class_name.c_str(), -1, &class_utf8[0], size_needed, NULL, NULL);
            }

            HMONITOR monitor = MonitorFromWindow(w.hwnd, MONITOR_DEFAULTTONEAREST);
            UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
            double scale = static_cast<double>(dpi) / 96.0;

            map[flutter::EncodableValue("appBundleId")] = flutter::EncodableValue(class_utf8);
            map[flutter::EncodableValue("windowTitle")] = flutter::EncodableValue(title_utf8);
            map[flutter::EncodableValue("x")] = flutter::EncodableValue(static_cast<double>(w.rect.left) / scale);
            map[flutter::EncodableValue("y")] = flutter::EncodableValue(static_cast<double>(w.rect.top) / scale);
            map[flutter::EncodableValue("width")] = flutter::EncodableValue(static_cast<double>(w.rect.right - w.rect.left) / scale);
            map[flutter::EncodableValue("height")] = flutter::EncodableValue(static_cast<double>(w.rect.bottom - w.rect.top) / scale);
            map[flutter::EncodableValue("isMinimized")] = flutter::EncodableValue(w.is_minimized);
            map[flutter::EncodableValue("isVisible")] = flutter::EncodableValue(true);

            encodable_list.push_back(flutter::EncodableValue(map));
          }
          result->Success(flutter::EncodableValue(encodable_list));
        }
        else if (method_name == "showConstraintWindow") {
          result->Success();
        }
        else if (method_name == "hideConstraintWindow") {
          result->Success();
        }
        else if (method_name == "focusApp") {
          HWND hwnd = GetHandle();
          if (hwnd) {
            if (IsIconic(hwnd)) {
              ShowWindow(hwnd, SW_RESTORE);
            }
            SetForegroundWindow(hwnd);
            result->Success();
          } else {
            result->Error("WINDOW_ERROR", "Could not get window handle");
          }
        }
        else if (method_name == "setWindowLevel") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto level_it = args->find(flutter::EncodableValue("level"));
            if (level_it != args->end()) {
              std::string level = std::get<std::string>(level_it->second);
              HWND hwnd = GetHandle();
              if (level == "floating" || level == "screenSaver") {
                SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
              } else {
                SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
              }
            }
          }
          result->Success();
        }
        else if (method_name == "showOverlay") {
           const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
           std::map<std::string, flutter::EncodableValue> params;
           bool strict = false;
           if (args) {
             for (const auto& kv : *args) {
                 if (std::holds_alternative<std::string>(kv.first)) {
                     params[std::get<std::string>(kv.first)] = kv.second;
                 }
             }
             auto it = params.find("strictMode");
             if (it != params.end() && std::holds_alternative<bool>(it->second)) {
                 strict = std::get<bool>(it->second);
             }
           }
           OverlayWindowManager::GetInstance()->ShowOverlay(strict, params);
           if (args) {
               // Schedule a delayed update to ensure Dart is ready
               auto map = *args;
               HWND hwnd = GetHandle();
               std::thread([hwnd, map]() {
                   Sleep(1000);
                   auto* task = new std::function<void()>([map]() {
                       OverlayWindowManager::GetInstance()->UpdateOverlayData(map);
                   });
                   PostMessage(hwnd, WM_USER + 10, reinterpret_cast<WPARAM>(task), 0);
               }).detach();
           }
           result->Success();
        }
        else if (method_name == "updateOverlayData") {
           const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
           if (args) {
               OverlayWindowManager::GetInstance()->UpdateOverlayData(*args);
           }
           result->Success();
        }
        else if (method_name == "hideOverlay") {
           OverlayWindowManager::GetInstance()->HideOverlay();
           result->Success();
        }
        else if (method_name == "setIgnoreMouseEvents") {
           const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
           if (args) {
             auto ignore_it = args->find(flutter::EncodableValue("ignore"));
             if (ignore_it != args->end()) {
               SetIgnoreMouseEvents(std::get<bool>(ignore_it->second));
             }
           }
           result->Success();
        }
        else if (method_name == "getAppearance") {
           // Simple dark mode detection on Windows
           bool is_dark = false;
           HKEY hKey;
           if (RegOpenKeyEx(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
             DWORD value;
             DWORD size = sizeof(value);
             if (RegQueryValueEx(hKey, L"AppsUseLightTheme", NULL, NULL, (LPBYTE)&value, &size) == ERROR_SUCCESS) {
               is_dark = (value == 0);
             }
             RegCloseKey(hKey);
           }
           result->Success(flutter::EncodableValue(is_dark ? "dark" : "light"));
        }
        else if (method_name == "showCompanion") {
           const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
           if (args) {
             std::string theme_id = "grey_cat";
             std::string pet_name = "Mochi";
             double scale = 6.0;
             bool click_through = false;

             auto it = args->find(flutter::EncodableValue("themeId"));
             if (it != args->end()) theme_id = std::get<std::string>(it->second);

             it = args->find(flutter::EncodableValue("petName"));
             if (it != args->end()) pet_name = std::get<std::string>(it->second);

             it = args->find(flutter::EncodableValue("scale"));
             if (it != args->end()) scale = std::get<double>(it->second);

             it = args->find(flutter::EncodableValue("clickThrough"));
             if (it != args->end()) click_through = std::get<bool>(it->second);

             CompanionWindowManager::GetInstance()->ShowCompanion(theme_id, pet_name, scale, click_through);
           }
           result->Success();
        }
        else if (method_name == "hideCompanion") {
           CompanionWindowManager::GetInstance()->HideCompanion();
           result->Success();
        }
        else if (method_name.find("updateCompanion") != std::string::npos || 
                 method_name == "triggerCompanionState" ||
                 method_name == "setCompanionWandering" ||
                 method_name == "setCompanionFollowMouse") {
           const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
           if (args) {
               std::map<std::string, flutter::EncodableValue> params;
               // Convert encodable map to standard map for UpdateParams
               for (const auto& [key, value] : *args) {
                   if (std::holds_alternative<std::string>(key)) {
                       params[std::get<std::string>(key)] = value;
                   }
               }
               CompanionWindowManager::GetInstance()->UpdateParams(params);
           }
           result->Success();
        }
        else if (method_name == "requestCalendarPermissions") {
          auto result_ptr = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
          HWND hwnd = GetHandle();
          std::thread([this, hwnd, result_ptr]() {
            winrt::init_apartment();
            auto perm = calendar_bridge_->RequestCalendarPermissions();
            auto* task = new std::function<void()>([perm, result_ptr]() {
              result_ptr->Success(flutter::EncodableValue(perm));
            });
            PostMessage(hwnd, WM_USER + 10, reinterpret_cast<WPARAM>(task), 0);
          }).detach();
        }
        else if (method_name == "hasCalendarPermissions") {
          auto result_ptr = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
          HWND hwnd = GetHandle();
          std::thread([this, hwnd, result_ptr]() {
            winrt::init_apartment();
            auto status = calendar_bridge_->GetCalendarPermissionStatus();
            auto* task = new std::function<void()>([status, result_ptr]() {
              result_ptr->Success(flutter::EncodableValue(status == "granted"));
            });
            PostMessage(hwnd, WM_USER + 10, reinterpret_cast<WPARAM>(task), 0);
          }).detach();
        }
        else if (method_name == "getCalendarPermissionStatus") {
          auto result_ptr = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
          HWND hwnd = GetHandle();
          std::thread([this, hwnd, result_ptr]() {
            winrt::init_apartment();
            auto status = calendar_bridge_->GetCalendarPermissionStatus();
            auto* task = new std::function<void()>([status, result_ptr]() {
              result_ptr->Success(flutter::EncodableValue(status));
            });
            PostMessage(hwnd, WM_USER + 10, reinterpret_cast<WPARAM>(task), 0);
          }).detach();
        }
        else if (method_name == "openCalendarSettings") {
          calendar_bridge_->OpenCalendarSettings();
          result->Success();
        }
        else if (method_name == "getUpcomingCalendarEvents") {
          int minutes = 240;
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("windowMinutes"));
            if (it != args->end()) {
              if (std::holds_alternative<int>(it->second)) {
                minutes = std::get<int>(it->second);
              } else if (std::holds_alternative<int64_t>(it->second)) {
                minutes = static_cast<int>(std::get<int64_t>(it->second));
              } else if (std::holds_alternative<double>(it->second)) {
                minutes = static_cast<int>(std::get<double>(it->second));
              }
            }
          }
          auto result_ptr = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
          HWND hwnd = GetHandle();
          std::thread([this, hwnd, minutes, result_ptr]() {
            winrt::init_apartment();
            auto events = calendar_bridge_->GetUpcomingCalendarEvents(minutes);
            auto* task = new std::function<void()>([events, result_ptr]() {
              result_ptr->Success(flutter::EncodableValue(events));
            });
            PostMessage(hwnd, WM_USER + 10, reinterpret_cast<WPARAM>(task), 0);
          }).detach();
        }
        else if (method_name == "getCalendars") {
          auto result_ptr = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
          HWND hwnd = GetHandle();
          std::thread([this, hwnd, result_ptr]() {
            winrt::init_apartment();
            auto calendars = calendar_bridge_->GetCalendars();
            auto* task = new std::function<void()>([calendars, result_ptr]() {
              result_ptr->Success(flutter::EncodableValue(calendars));
            });
            PostMessage(hwnd, WM_USER + 10, reinterpret_cast<WPARAM>(task), 0);
          }).detach();
        }
        else if (method_name == "getEvents") {
          int64_t start_ms = 0;
          int64_t end_ms = 0;
          std::vector<std::string> calendar_ids;
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("startMs"));
            if (it != args->end()) {
              if (std::holds_alternative<int64_t>(it->second)) {
                start_ms = std::get<int64_t>(it->second);
              } else if (std::holds_alternative<int>(it->second)) {
                start_ms = std::get<int>(it->second);
              } else if (std::holds_alternative<double>(it->second)) {
                start_ms = static_cast<int64_t>(std::get<double>(it->second));
              }
            }
            it = args->find(flutter::EncodableValue("endMs"));
            if (it != args->end()) {
              if (std::holds_alternative<int64_t>(it->second)) {
                end_ms = std::get<int64_t>(it->second);
              } else if (std::holds_alternative<int>(it->second)) {
                end_ms = std::get<int>(it->second);
              } else if (std::holds_alternative<double>(it->second)) {
                end_ms = static_cast<int64_t>(std::get<double>(it->second));
              }
            }
            it = args->find(flutter::EncodableValue("calendarIds"));
            if (it != args->end() && std::holds_alternative<flutter::EncodableList>(it->second)) {
              const auto& list = std::get<flutter::EncodableList>(it->second);
              for (const auto& val : list) {
                if (std::holds_alternative<std::string>(val)) {
                  calendar_ids.push_back(std::get<std::string>(val));
                }
              }
            }
          }
          auto result_ptr = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
          HWND hwnd = GetHandle();
          std::thread([this, hwnd, start_ms, end_ms, calendar_ids, result_ptr]() {
            winrt::init_apartment();
            auto events = calendar_bridge_->GetEvents(start_ms, end_ms, calendar_ids);
            auto* task = new std::function<void()>([events, result_ptr]() {
              result_ptr->Success(flutter::EncodableValue(events));
            });
            PostMessage(hwnd, WM_USER + 10, reinterpret_cast<WPARAM>(task), 0);
          }).detach();
        }
        else if (method_name == "showPipWindow") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          std::map<std::string, flutter::EncodableValue> params;
          if (args) {
            for (const auto& [key, value] : *args) {
              if (std::holds_alternative<std::string>(key)) {
                params[std::get<std::string>(key)] = value;
              }
            }
          }
          CompanionWindowManager::GetInstance()->ShowPiP(params);
          result->Success();
        }
        else if (method_name == "hidePipWindow") {
          CompanionWindowManager::GetInstance()->HidePiP();
          result->Success();
        }

        else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::OnDestroy() {
  KillTimer(GetHandle(), 1);

  // Decrement keyboard hook reference count for overlay windows and unhook if needed
  if (keyboard_hook_ && is_overlay_) {
    keyboard_hook_ref_count_--;
    if (keyboard_hook_ref_count_ <= 0) {
      UnhookWindowsHookEx(keyboard_hook_);
      keyboard_hook_ = nullptr;
      keyboard_hook_ref_count_ = 0;
    }
  }
  if (flutter_controller_) {
    IpcBridgeManager::GetInstance()->UnregisterEngine(flutter_controller_->engine());
    flutter_controller_ = nullptr;
  }

  if (main_window_ == this) {
    main_window_ = nullptr;
  }

  // If this is the main window, clean up all secondary windows and engines
  if (!is_companion_ && !is_overlay_ && !is_pip_) {
    CompanionWindowManager::GetInstance()->HideCompanion();
    CompanionWindowManager::GetInstance()->HidePiP();
    OverlayWindowManager::GetInstance()->HideOverlay();
  }

  Win32Window::OnDestroy();
}

// Configure window as full-screen overlay
void FlutterWindow::ConfigureAsOverlay() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  // Store original styles for restoration.
  original_style_    = GetWindowLong(hwnd, GWL_STYLE);
  original_ex_style_ = GetWindowLong(hwnd, GWL_EXSTYLE);

  // Window was created with WS_POPUP (no NC area). Clear overlapped bits
  // defensively and ensure popup is set.
  LONG style = GetWindowLong(hwnd, GWL_STYLE);
  style &= ~WS_OVERLAPPEDWINDOW;
  style |= WS_POPUP;
  SetWindowLong(hwnd, GWL_STYLE, style);

  // Enable layered mode for DWM composition and hide from taskbar/Alt-Tab.
  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  exStyle |= WS_EX_LAYERED;
  exStyle |= WS_EX_TOOLWINDOW;
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);

  // Fully opaque — Flutter renders the surface content; DWM composites it.
  SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);

  // Apply style changes and raise to topmost WITHOUT moving or resizing.
  // The window was created at the exact physical monitor size (WS_POPUP +
  // physical_coords=true), so there is no size correction needed here.
  // Resizing here would send WM_SIZE while Flutter is still initialising
  // which triggers an abort() in the embedder. Show() does the final
  // positioning once the engine has rendered its first frame.
  SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);

  is_overlay_mode_ = true;

  // Low-level keyboard hook to block virtual desktop switch gestures (Win+Ctrl
  // arrows, Win+Tab) while the break overlay is active.
  if (!keyboard_hook_) {
    keyboard_hook_ = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc,
                                      GetModuleHandle(NULL), 0);
  }
  if (keyboard_hook_) {
    keyboard_hook_ref_count_++;
  }
}

// Reset window to normal state
void FlutterWindow::ResetToNormal() {
  if (!is_overlay_mode_) return;

  HWND hwnd = GetHandle();
  if (!hwnd) return;

  // Restore original styles
  SetWindowLong(hwnd, GWL_STYLE, original_style_);
  SetWindowLong(hwnd, GWL_EXSTYLE, original_ex_style_);

  // Remove topmost status and apply style changes
  SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);

  is_overlay_mode_ = false;

  // Remove keyboard hook
  if (keyboard_hook_) {
    UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
  }
}

// Set window transparency (opacity 0.0 - 1.0)
void FlutterWindow::SetWindowTransparency(double opacity) {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  // Bypass native layered window opacity for PiP windows to preserve transparent rounded corners
  if (is_pip_) return;

  // Clamp opacity to valid range
  opacity = opacity < 0.0 ? 0.0 : (opacity > 1.0 ? 1.0 : opacity);
  
  // Set layered window attributes (alpha blending)
  BYTE alpha = static_cast<BYTE>(opacity * 255);
  SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_ALPHA);
}

// Set window to ignore mouse events (click-through)
void FlutterWindow::SetIgnoreMouseEvents(bool ignore) {
  ignore_mouse_events_ = ignore;

  HWND hwnd = GetHandle();
  if (!hwnd) return;

  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  if (ignore) {
    exStyle |= WS_EX_TRANSPARENT;  // Mouse events pass through
  } else {
    exStyle &= ~WS_EX_TRANSPARENT; // Normal mouse interaction
  }
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);

  // Trigger WM_NCHITTEST update
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED | SWP_NOACTIVATE);
}

void FlutterWindow::SetupOverlayBridge() {
  // Setup com.breakmate.desktop/bridge for overlay isolate (needs getOverlayData)
  if (is_overlay_) {
    bridge_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        flutter_controller_->engine()->messenger(), "com.breakmate.desktop/bridge",
        &flutter::StandardMethodCodec::GetInstance());

    bridge_channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
          const std::string& method_name = call.method_name();

          if (method_name == "getOverlayData") {
            auto data = OverlayWindowManager::GetInstance()->GetLastShowArgs();
            result->Success(flutter::EncodableValue(data));
          }
          else if (method_name == "checkIsMainEngine") {
            result->Success(flutter::EncodableValue(false));
          }
          else if (method_name == "hideOverlay") {
            OverlayWindowManager::GetInstance()->HideOverlay();
            result->Success();
          }
          else if (method_name == "skipBreak" || method_name == "completeBreak") {
            // Forward to main app directly on its bridge channel
            if (main_window_ && main_window_->GetBridgeChannel()) {
              main_window_->GetBridgeChannel()->InvokeMethod(
                  method_name, 
                  std::make_unique<flutter::EncodableValue>(flutter::EncodableMap()));
            }
            OverlayWindowManager::GetInstance()->HideOverlay();
            result->Success();
          }
          else if (method_name == "setIgnoreMouseEvents") {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (args) {
              auto ignore_it = args->find(flutter::EncodableValue("ignore"));
              if (ignore_it != args->end()) {
                SetIgnoreMouseEvents(std::get<bool>(ignore_it->second));
              }
            }
            result->Success();
          }
          else {
            result->NotImplemented();
          }
        });
  }

  overlay_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate/overlay",
      &flutter::StandardMethodCodec::GetInstance());

  overlay_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const std::string& method_name = call.method_name();

        if (method_name == "setStrictMode") {
          const auto* enabled = std::get_if<bool>(call.arguments());
          if (enabled) {
            // On Windows, strict mode means always on top + focus
            if (*enabled) {
              SetWindowPos(GetHandle(), HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
              SetForegroundWindow(GetHandle());
            } else {
              SetWindowPos(GetHandle(), HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
            }
          }
          result->Success();
        }
        else {
          result->NotImplemented();
        }
      });
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_NCHITTEST && ignore_mouse_events_) {
    return HTTRANSPARENT;
  }

  if (is_pip_) {
    switch (message) {
      case WM_NCCALCSIZE: {
        if (wparam == TRUE) {
          return 0; // Client area occupies the entire window (removing frame borders)
        }
        break;
      }
      case WM_NCHITTEST: {
        short x_pos = static_cast<short>(LOWORD(lparam));
        short y_pos = static_cast<short>(HIWORD(lparam));
        POINT pt = { x_pos, y_pos };
        ScreenToClient(hwnd, &pt);
        RECT rect;
        GetClientRect(hwnd, &rect);
        
        const int border_width = 8;
        
        bool left = pt.x < border_width;
        bool right = pt.x >= rect.right - border_width;
        bool top = pt.y < border_width;
        bool bottom = pt.y >= rect.bottom - border_width;
        
        if (top && left) return HTTOPLEFT;
        if (top && right) return HTTOPRIGHT;
        if (bottom && left) return HTBOTTOMLEFT;
        if (bottom && right) return HTBOTTOMRIGHT;
        if (left) return HTLEFT;
        if (right) return HTRIGHT;
        if (top) return HTTOP;
        if (bottom) return HTBOTTOM;

        // Custom drag handle region:
        // Card is inset by 12px margin. Drag handle height is 32px.
        // So drag handle runs vertically from y = 12 to y = 44.
        // Avoid the close button region on the top-right of the card.
        if (pt.y >= 12 && pt.y < 44 && pt.x >= 12 && pt.x < (rect.right - 50)) {
          return HTCAPTION;
        }

        break;
      }
      case WM_GETMINMAXINFO: {
        MINMAXINFO* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
        mmi->ptMinTrackSize.x = 200;
        mmi->ptMinTrackSize.y = 200;
        mmi->ptMaxTrackSize.x = 600;
        mmi->ptMaxTrackSize.y = 600;
        return 0;
      }
    }
  }

  if (message == WM_SIZE && is_overlay_) {
    HWND child_hwnd = GetChildContent();
    if (child_hwnd) {
      RECT rect;
      ::GetClientRect(hwnd, &rect);
      ::MoveWindow(child_hwnd, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_USER + 10: {
      auto* task = reinterpret_cast<std::function<void()>*>(wparam);
      if (task) {
        (*task)();
        delete task;
      }
      return 0;
    }
    case WM_DISPLAYCHANGE:
    case WM_DPICHANGED:
      if (this == main_window_) {
        if (g_display_stream_handler) {
          g_display_stream_handler->SendUpdate();
        }
        OverlayWindowManager::GetInstance()->OnDisplayChange();
      } else if (is_overlay_) {
        // Prevent default Win32Window handler from resizing/moving the overlay
        // window based on the OS suggested rect. It must remain full-screen
        // covering its target monitor.
        HWND child_hwnd = GetChildContent();
        if (child_hwnd) {
          RECT rect;
          ::GetClientRect(hwnd, &rect);
          ::MoveWindow(child_hwnd, rect.left, rect.top, rect.right - rect.left - 1, rect.bottom - rect.top, TRUE);
          ::MoveWindow(child_hwnd, rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top, TRUE);
        }
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
    case WM_TIMER:
      if (wparam == 1) {
        if (g_focus_mode_handler) {
          g_focus_mode_handler->SendUpdate(bridge_utils::IsFocusModeActive());
        }
        if (g_meeting_detection_handler) {
          std::string bundle_id;
          bool is_active = bridge_utils::IsMeetingActive(bundle_id);
          g_meeting_detection_handler->SendUpdate(is_active, bundle_id);
        }
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
