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
  DestroyAll();
}

struct OverlayEnumData {
  std::vector<OverlayWindowManager::OverlayEntry>* windows;
  std::vector<OverlayWindowManager::OverlayEntry>* warm_pool;
  const std::map<std::string, flutter::EncodableValue>* args;
  bool ignore_mouse;
  bool is_strict_mode;
  bool show_on_all_displays;
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

  bool show_on_all_displays = true;
  auto it_all = args.find("showOnAllDisplays");
  if (it_all != args.end() && std::holds_alternative<bool>(it_all->second)) {
    show_on_all_displays = std::get<bool>(it_all->second);
  }

  OverlayEnumData enum_data = {&overlay_windows_, &warm_pool_, &args, ignore_mouse, is_strict_mode, show_on_all_displays};

  auto monitor_enum_proc = [](HMONITOR hMonitor, HDC hdcMonitor, LPRECT lprcMonitor, LPARAM dwData) -> BOOL {
    auto data = reinterpret_cast<OverlayEnumData*>(dwData);
    auto windows = data->windows;
    auto warm_pool = data->warm_pool;

    MONITORINFO monitorInfo = {};
    monitorInfo.cbSize = sizeof(MONITORINFO);
    RECT monitorRect = *lprcMonitor;
    if (GetMonitorInfo(hMonitor, &monitorInfo)) {
      monitorRect = monitorInfo.rcMonitor;
      // If we only show on the primary monitor, skip if this is not primary
      if (!data->show_on_all_displays && !(monitorInfo.dwFlags & MONITORINFOF_PRIMARY)) {
        return TRUE;
      }
    }

    // Reuse an already-warm window for this monitor if we have one —
    // avoids a cold FlutterEngine start (the dominant cost of "why does
    // Preview take seconds to appear") entirely.
    for (auto pool_it = warm_pool->begin(); pool_it != warm_pool->end(); ++pool_it) {
      if (pool_it->monitor != hMonitor) continue;

      OverlayWindowManager::OverlayEntry entry = std::move(*pool_it);
      warm_pool->erase(pool_it);

      entry.window->SetIgnoreMouseEvents(data->ignore_mouse);
      // Re-applies position/size/topmost and does the right SW_SHOW* pick
      // based on ignore_mouse_events_ — the same overlay-specific setup a
      // freshly created window gets from its own Show() call below, which
      // a plain ShowWindow(SW_SHOW) here would skip.
      entry.window->Show();
      if (data->is_strict_mode) {
        SetForegroundWindow(entry.window->GetHandle());
      }

      // The engine is already running — push fresh data immediately
      // rather than waiting on the cold-start fallback broadcast that
      // showOverlay() schedules for newly created windows.
      if (entry.window->GetEngine()) {
        flutter::EncodableMap data_map;
        for (const auto& [key, value] : *data->args) {
          data_map[flutter::EncodableValue(key)] = value;
        }
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            entry.window->GetEngine()->messenger(), "com.breakmate.desktop/bridge",
            &flutter::StandardMethodCodec::GetInstance());
        channel->InvokeMethod("updateOverlayData", std::make_unique<flutter::EncodableValue>(data_map));
      }

      windows->push_back(std::move(entry));
      return TRUE;
    }

    flutter::DartProject project(L"data");
    project.set_dart_entrypoint("overlayMain");

    auto window = std::make_unique<FlutterWindow>(project);
    window->SetIsOverlay(true);

    // Since Win32Window::Create() has been updated to bypass scale factor multiplication
    // for WS_POPUP style windows, we can pass physical coordinate values directly.
    int physicalLeft   = monitorRect.left;
    int physicalTop    = monitorRect.top;
    int physicalWidth  = monitorRect.right  - monitorRect.left;
    int physicalHeight = monitorRect.bottom - monitorRect.top;

    UINT dpi = FlutterDesktopGetDpiForMonitor(hMonitor);
    double scale = static_cast<double>(dpi) / 96.0;

    printf("[OverlayWindowManager] Monitor: %p, Physical Rect: {%ld, %ld, %ld, %ld}, DPI: %u, Scale: %f\n",
           (void*)hMonitor, monitorRect.left, monitorRect.top, monitorRect.right, monitorRect.bottom, dpi, scale);
    fflush(stdout);

    Win32Window::Point origin(physicalLeft, physicalTop);
    Win32Window::Size  size(physicalWidth, physicalHeight);

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

      window->SetOverlayRect(monitorRect);

      printf("[OverlayWindowManager] Calling Show() for monitor: %p\n", (void*)hMonitor);
      fflush(stdout);
      window->Show();
      printf("[OverlayWindowManager] Show() completed for monitor: %p\n", (void*)hMonitor);
      fflush(stdout);

      if (data->is_strict_mode) {
        SetForegroundWindow(window->GetHandle());
      }

      IpcBridgeManager::GetInstance()->RegisterEngine(window->GetEngine());
      windows->push_back(OverlayWindowManager::OverlayEntry{hMonitor, std::move(window)});
    }
    return TRUE;
  };

  EnumDisplayMonitors(NULL, NULL, monitor_enum_proc, reinterpret_cast<LPARAM>(&enum_data));
}

void OverlayWindowManager::HideOverlay() {
  if (overlay_windows_.empty()) return;

  // Keep the engines alive, hidden, for instant reuse next time — see
  // `warm_pool_`. They're only ever actually torn down when the display
  // configuration changes (their window frames/DPI would be stale) or the
  // app is quitting (see DestroyAll).
  for (auto& entry : overlay_windows_) {
    if (entry.window) {
      ShowWindow(entry.window->GetHandle(), SW_HIDE);
    }
  }
  for (auto& entry : overlay_windows_) {
    warm_pool_.push_back(std::move(entry));
  }
  overlay_windows_.clear();
}

void OverlayWindowManager::DestroyEntries(std::vector<OverlayEntry>& entries) {
  for (auto& entry : entries) {
    if (entry.window && entry.window->GetEngine()) {
      IpcBridgeManager::GetInstance()->UnregisterEngine(entry.window->GetEngine());
    }
    if (entry.window) {
      entry.window->Destroy();
    }
  }
  entries.clear();
}

void OverlayWindowManager::DestroyAll() {
  DestroyEntries(overlay_windows_);
  DestroyEntries(warm_pool_);
}

void OverlayWindowManager::UpdateOverlayData(const flutter::EncodableMap& data) {
  for (auto& entry : overlay_windows_) {
    if (entry.window && entry.window->GetEngine()) {
      // Push live timer/template data into every overlay engine so each
      // monitor stays visually synchronized.
      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          entry.window->GetEngine()->messenger(), "com.breakmate.desktop/bridge",
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
  for (auto& entry : overlay_windows_) {
    if (entry.window && entry.window->GetEngine()) {
      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          entry.window->GetEngine()->messenger(), "com.breakmate.desktop/bridge",
          &flutter::StandardMethodCodec::GetInstance());
      channel->InvokeMethod(
          "skipBreak",
          std::make_unique<flutter::EncodableValue>(flutter::EncodableMap()));
    }
  }
}

void OverlayWindowManager::OnDisplayChange() {
  bool was_active = !overlay_windows_.empty();
  if (!was_active && warm_pool_.empty()) return;

  // A real display/DPI change means every window frame (active or pooled)
  // is stale — unlike a normal hide, these can't be kept warm for reuse,
  // they have to be rebuilt against the new monitor layout.
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

  DestroyAll();
  if (was_active) {
    ShowOverlay(strict, args);
  }
}
