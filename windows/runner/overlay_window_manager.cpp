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
    return; // Already showing
  }

  // Store args for getOverlayData calls from overlay isolates
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

    Win32Window::Point origin(lprcMonitor->left, lprcMonitor->top);
    Win32Window::Size size(lprcMonitor->right - lprcMonitor->left, lprcMonitor->bottom - lprcMonitor->top);

    if (window->Create(L"StandupOverlay", origin, size)) {
      window->SetQuitOnClose(false);
      window->ConfigureAsOverlay();
      
      if (data->ignore_mouse) {
        window->SetIgnoreMouseEvents(true);
      }
      
      // Override position to this monitor
      SetWindowPos(window->GetHandle(), HWND_TOPMOST,
                   lprcMonitor->left, lprcMonitor->top,
                   lprcMonitor->right - lprcMonitor->left,
                   lprcMonitor->bottom - lprcMonitor->top,
                   SWP_NOACTIVATE);

      window->Show();
      
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
      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          window->GetEngine()->messenger(), "com.breakmate.desktop/bridge",
          &flutter::StandardMethodCodec::GetInstance());
      
      channel->InvokeMethod("updateOverlayData", std::make_unique<flutter::EncodableValue>(data));
    }
  }
}
