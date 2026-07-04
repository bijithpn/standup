#include "overlay_window_manager.h"
#include <windows.h>
#include "ipc_bridge_manager.h"

OverlayWindowManager* OverlayWindowManager::instance_ = nullptr;

OverlayWindowManager* OverlayWindowManager::GetInstance() {
  if (!instance_) {
    instance_ = new OverlayWindowManager();
  }
  return instance_;
}

OverlayWindowManager::OverlayWindowManager() {}

OverlayWindowManager::~OverlayWindowManager() {
  HideOverlay();
}

struct OverlayEnumData {
  std::vector<std::unique_ptr<FlutterWindow>>* windows;
  bool ignore_mouse;
  bool is_strict_mode;
};

void OverlayWindowManager::ShowOverlay(bool is_strict_mode, const std::map<std::string, flutter::EncodableValue>& args) {
  if (!overlay_windows_.empty()) {
    return; // A break overlay is already active across the current monitor set.
  }

  // Keep the launch payload available for overlay isolates that initialize
  // their MethodChannel handler after the native window is already visible.
  last_show_args_.clear();
  for (const auto& [key, value] : args) {
    last_show_args_[flutter::EncodableValue(key)] = value;
  }

  bool ignore_mouse = false;
  auto it = args.find("ignoreMouseEvents");
  if (it != args.end() && std::holds_alternative<bool>(it->second)) {
    ignore_mouse = std::get<bool>(it->second);
  }

  OverlayEnumData enum_data = {&overlay_windows_, ignore_mouse, is_strict_mode};

  auto monitor_enum_proc = [](HMONITOR hMonitor, HDC hdcMonitor, LPRECT lprcMonitor, LPARAM dwData) -> BOOL {
    auto data = reinterpret_cast<OverlayEnumData*>(dwData);
    auto windows = data->windows;

    flutter::DartProject project(L"data");
    project.set_dart_entrypoint("overlayMain");

    auto window = std::make_unique<FlutterWindow>(project);
    window->SetIsOverlay(true);

    // EnumDisplayMonitors supplies physical pixel coordinates. Win32Window::Create()
    // expects logical coordinates and scales them internally using the monitor's
    // DPI. We must first convert physical to logical to prevent double-scaling.
    UINT dpiX = 96, dpiY = 96;
    HMODULE hUser32 = LoadLibrary(L"user32.dll");
    if (hUser32) {
      typedef UINT(STDAPICALLTYPE * GetDpiForMonitorFn)(HMONITOR, int, UINT*, UINT*);
      auto getDpiForMonitor =
          reinterpret_cast<GetDpiForMonitorFn>(GetProcAddress(hUser32, "GetDpiForMonitor"));
      if (getDpiForMonitor) {
        getDpiForMonitor(hMonitor, 0 /* MDT_EFFECTIVE_DPI */, &dpiX, &dpiY);
      }
      FreeLibrary(hUser32);
    }
    double scale = static_cast<double>(dpiX) / 96.0;

    int logicalLeft   = static_cast<int>(lprcMonitor->left   / scale);
    int logicalTop    = static_cast<int>(lprcMonitor->top    / scale);
    int logicalWidth  = static_cast<int>((lprcMonitor->right  - lprcMonitor->left) / scale);
    int logicalHeight = static_cast<int>((lprcMonitor->bottom - lprcMonitor->top)  / scale);

    printf("[OverlayWindowManager] Monitor: %p, Physical Rect: {%ld, %ld, %ld, %ld}, DPI: %u, Scale: %f\n",
           (void*)hMonitor, lprcMonitor->left, lprcMonitor->top, lprcMonitor->right, lprcMonitor->bottom, dpiX, scale);
    printf("[OverlayWindowManager] Computed Logical Rect: {%d, %d, %d, %d}\n",
           logicalLeft, logicalTop, logicalWidth, logicalHeight);
    fflush(stdout);

    Win32Window::Point origin(logicalLeft, logicalTop);
    Win32Window::Size  size(logicalWidth, logicalHeight);

    // Using WS_POPUP ensures no non-client area (titlebar/borders) is present,
    // so GetClientArea() in OnCreate() returns the full monitor dimensions, and
    // FlutterViewController is sized to the full screen from the start.
    bool success = window->Create(L"StandupOverlay", origin, size, hMonitor, WS_POPUP);
    printf("[OverlayWindowManager] Create success: %d for monitor: %p\n", success, (void*)hMonitor);
    fflush(stdout);

    if (success) {
      window->SetQuitOnClose(false);
      window->ConfigureAsOverlay();

      if (data->ignore_mouse) {
        window->SetIgnoreMouseEvents(true);
      }

      window->SetOverlayRect(*lprcMonitor);

      printf("[OverlayWindowManager] Calling Show() for monitor: %p\n", (void*)hMonitor);
      fflush(stdout);
      window->Show();
      printf("[OverlayWindowManager] Show() completed for monitor: %p\n", (void*)hMonitor);
      fflush(stdout);

      if (data->is_strict_mode) {
        SetForegroundWindow(window->GetHandle());
      }

      IpcBridgeManager::GetInstance()->RegisterEngine(window->GetEngine());
      windows->push_back(std::move(window));
    }
    return TRUE;
  };

  EnumDisplayMonitors(NULL, NULL, monitor_enum_proc, reinterpret_cast<LPARAM>(&enum_data));
}

void OverlayWindowManager::HideOverlay() {
  for (auto& window : overlay_windows_) {
    if (window && window->GetEngine()) {
      IpcBridgeManager::GetInstance()->UnregisterEngine(window->GetEngine());
    }
    if (window) {
      window->Destroy();
    }
  }
  overlay_windows_.clear();
}

void OverlayWindowManager::UpdateOverlayData(const flutter::EncodableMap& data) {
  for (auto& window : overlay_windows_) {
    if (window && window->GetEngine()) {
      // Push live timer/template data into every overlay engine so each
      // monitor stays visually synchronized.
      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          window->GetEngine()->messenger(), "com.breakmate.desktop/bridge",
          &flutter::StandardMethodCodec::GetInstance());
      
      channel->InvokeMethod("updateOverlayData", std::make_unique<flutter::EncodableValue>(data));
    }
  }
}

void OverlayWindowManager::HandleEscapeKey() {
  if (overlay_windows_.empty()) return;

  // Respect strict mode: if the break cannot be skipped, swallow the key.
  bool strict = false;
  auto it = last_show_args_.find(flutter::EncodableValue("strictMode"));
  if (it != last_show_args_.end() && std::holds_alternative<bool>(it->second)) {
    strict = std::get<bool>(it->second);
  }
  if (strict) return;

  // Send skipBreak to each overlay engine. The Dart bridge handler in
  // SetupOverlayBridge forwards this to the main engine and calls HideOverlay.
  for (auto& window : overlay_windows_) {
    if (window && window->GetEngine()) {
      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          window->GetEngine()->messenger(), "com.breakmate.desktop/bridge",
          &flutter::StandardMethodCodec::GetInstance());
      channel->InvokeMethod(
          "skipBreak",
          std::make_unique<flutter::EncodableValue>(flutter::EncodableMap()));
    }
  }
}

void OverlayWindowManager::OnDisplayChange() {
  if (overlay_windows_.empty()) return;

  // Re-create overlay windows to align with the new display configuration or DPI.
  bool strict = false;
  auto it = last_show_args_.find(flutter::EncodableValue("strictMode"));
  if (it != last_show_args_.end() && std::holds_alternative<bool>(it->second)) {
    strict = std::get<bool>(it->second);
  }

  std::map<std::string, flutter::EncodableValue> args;
  for (const auto& [key, value] : last_show_args_) {
    if (std::holds_alternative<std::string>(key)) {
      args[std::get<std::string>(key)] = value;
    }
  }

  HideOverlay();
  ShowOverlay(strict, args);
}
