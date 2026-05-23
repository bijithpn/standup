#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <shellapi.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler.h>

#include "flutter/generated_plugin_registrant.h"
#include "bridge_utils.h"
#include "companion_window_manager.h"
#include "overlay_window_plugin.h"
#include "display_bridge.h"

// ... rest of stream handlers ...

HHOOK FlutterWindow::keyboard_hook_ = nullptr;

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
  }
  return CallNextHookEx(keyboard_hook_, nCode, wParam, lParam);
}

class FocusModeStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  FocusModeStreamHandler() {}
  virtual ~FocusModeStreamHandler() {}

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
  virtual ~MeetingDetectionStreamHandler() {}

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

static FocusModeStreamHandler* g_focus_mode_handler = nullptr;
static MeetingDetectionStreamHandler* g_meeting_detection_handler = nullptr;
static DisplayStreamHandler* g_display_stream_handler = nullptr;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
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
  RegisterPlugins(flutter_controller_->engine());
  
  // Register the custom overlay window plugin (needed by both main and companion)
  RegisterOverlayWindowPlugin(flutter_controller_->engine());

  if (is_companion_) {
    // Companion window: only set up channels the companion widget needs.
    // Skipping SetupBridge / SetupEventChannels / SetupWindowBridge / timer
    // avoids crashes from APIs that only make sense in the main-app context.
    SetupCompanionBridge();
    SetupOverlayBridge();
  } else {
    // Main application window: full channel + event setup
    SetupBridge();
    SetupEventChannels();
    SetupWindowBridge();
    SetupOverlayBridge();
    RegisterDisplayBridge(flutter_controller_->engine(), &g_display_stream_handler);
    // Set up a timer to poll for focus/meeting updates (every 2 seconds)
    SetTimer(GetHandle(), 1, 2000, NULL);
  }
  
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
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
                SetWindowPos(GetHandle(), NULL, static_cast<int>(x), static_cast<int>(y), 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
            }
          }
          result->Success();
        }
        else if (method_name == "getWindowPosition") {
          RECT rect;
          GetWindowRect(GetHandle(), &rect);
          flutter::EncodableMap pos;
          pos[flutter::EncodableValue("x")] = flutter::EncodableValue(static_cast<double>(rect.left));
          pos[flutter::EncodableValue("y")] = flutter::EncodableValue(static_cast<double>(rect.top));
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
        else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::SetupCompanionBridge() {
  companion_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate.macos/companion_data",
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
      flutter_controller_->engine()->messenger(), "com.standup/focus_mode",
      &flutter::StandardMethodCodec::GetInstance());
  focus_mode_channel_->SetStreamHandler(std::move(focus_handler));

  auto meeting_handler = std::make_unique<MeetingDetectionStreamHandler>();
  g_meeting_detection_handler = meeting_handler.get();
  meeting_detection_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.standup/meeting_detection",
      &flutter::StandardMethodCodec::GetInstance());
  meeting_detection_channel_->SetStreamHandler(std::move(meeting_handler));
}

void FlutterWindow::SetupBridge() {
  bridge_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.breakmate.macos/bridge",
      &flutter::StandardMethodCodec::GetInstance());

  bridge_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method_name = call.method_name();

        if (method_name == "getIdleTime") {
          result->Success(flutter::EncodableValue(bridge_utils::GetIdleTime()));
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
           ConfigureAsOverlay();
           result->Success();
        }
        else if (method_name == "hideOverlay") {
           ResetToNormal();
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

        else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::OnDestroy() {
  KillTimer(GetHandle(), 1);
  if (keyboard_hook_) {
    UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// Configure window as full-screen overlay
void FlutterWindow::ConfigureAsOverlay() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  // Store original styles for restoration
  original_style_ = GetWindowLong(hwnd, GWL_STYLE);
  original_ex_style_ = GetWindowLong(hwnd, GWL_EXSTYLE);

  // Remove window borders and title bar (WS_CAPTION = WS_BORDER | WS_DLGFRAME)
  LONG style = GetWindowLong(hwnd, GWL_STYLE);
  style &= ~WS_CAPTION;      // Remove title bar
  style &= ~WS_THICKFRAME;   // Remove resize border
  style &= ~WS_MINIMIZEBOX;  // Remove minimize button
  style &= ~WS_MAXIMIZEBOX;  // Remove maximize button
  SetWindowLong(hwnd, GWL_STYLE, style);

  // Add layered and topmost extended styles
  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  exStyle |= WS_EX_LAYERED;      // Enable transparency
  exStyle |= WS_EX_TOOLWINDOW;   // Hide from taskbar
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);

  // Set window as topmost (above all other windows)
  SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  // Get screen dimensions for full-screen
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitorInfo = {};
  monitorInfo.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(monitor, &monitorInfo);

  // Set to full-screen
  SetWindowPos(hwnd, HWND_TOPMOST,
               monitorInfo.rcMonitor.left,
               monitorInfo.rcMonitor.top,
               monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left,
               monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top,
               SWP_NOACTIVATE);

  is_overlay_mode_ = true;

  // Set keyboard hook to block swiping spaces
  if (!keyboard_hook_) {
    keyboard_hook_ = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandle(NULL), 0);
  }
}

// Reset window to normal state
void FlutterWindow::ResetToNormal() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  // Restore original styles
  SetWindowLong(hwnd, GWL_STYLE, original_style_);
  SetWindowLong(hwnd, GWL_EXSTYLE, original_ex_style_);

  // Remove topmost status
  SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

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

  // Clamp opacity to valid range
  opacity = opacity < 0.0 ? 0.0 : (opacity > 1.0 ? 1.0 : opacity);
  
  // Set layered window attributes (alpha blending)
  BYTE alpha = static_cast<BYTE>(opacity * 255);
  SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_ALPHA);
}

// Set window to ignore mouse events (click-through)
void FlutterWindow::SetIgnoreMouseEvents(bool ignore) {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  if (ignore) {
    exStyle |= WS_EX_TRANSPARENT;  // Mouse events pass through
  } else {
    exStyle &= ~WS_EX_TRANSPARENT; // Normal mouse interaction
  }
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);
}

void FlutterWindow::SetupOverlayBridge() {
  overlay_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.standup/overlay",
      &flutter::StandardMethodCodec::GetInstance());

  overlay_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const std::string& method_name = call.method_name();
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

        if (method_name == "setStrictMode") {
          if (args) {
            auto enabled_it = args->find(flutter::EncodableValue("enabled"));
            if (enabled_it != args->end()) {
              // On Windows, strict mode means always on top + focus
              bool enabled = std::get<bool>(enabled_it->second);
              if (enabled) {
                SetWindowPos(GetHandle(), HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
                SetForegroundWindow(GetHandle());
              } else {
                SetWindowPos(GetHandle(), HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
              }
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
    case WM_DISPLAYCHANGE:
    case WM_DPICHANGED:
      if (g_display_stream_handler) {
        g_display_stream_handler->SendUpdate();
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
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
