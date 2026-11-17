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

using ArgMap = std::map<std::string, flutter::EncodableValue>;

static std::string StringArg(const ArgMap& args, const char* key, const char* fallback) {
  auto it = args.find(key);
  return it != args.end() && std::holds_alternative<std::string>(it->second)
             ? std::get<std::string>(it->second)
             : fallback;
}

static double NumberArg(const ArgMap& args, const char* key, double fallback) {
  auto it = args.find(key);
  if (it == args.end()) return fallback;
  if (auto* i = std::get_if<int32_t>(&it->second)) return *i;
  if (auto* l = std::get_if<int64_t>(&it->second)) return static_cast<double>(*l);
  if (auto* d = std::get_if<double>(&it->second)) return *d;
  return fallback;
}

static bool IsCompact(const ArgMap& args) {
  std::string type = StringArg(args, "type", StringArg(args, "overlayType", "breakScreen").c_str());
  return StringArg(args, "windowMode", "immersive") == "compact" && type == "breakScreen";
}

// Card size plus a 16px margin per side (so the card's shadow is not clipped),
// pinned to a corner of the monitor work area. Physical pixels.
static RECT CompactRect(HMONITOR monitor, const ArgMap& args) {
  MONITORINFO info = {};
  info.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(monitor, &info);
  double scale = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  int w = static_cast<int>((NumberArg(args, "compactWidth", 360) + 32) * scale);
  int h = static_cast<int>((NumberArg(args, "compactHeight", 244) + 32) * scale);
  std::string corner = StringArg(args, "compactCorner", "bottomRight");
  const RECT& work = info.rcWork;
  int left = corner.find("Left") != std::string::npos ? work.left : work.right - w;
  int top = corner.rfind("top", 0) == 0 ? work.top : work.bottom - h;
  return RECT{left, top, left + w, top + h};
}

static flutter::EncodableMap ToEncodableMap(const ArgMap& args) {
  flutter::EncodableMap map;
  for (const auto& [key, value] : args) map[flutter::EncodableValue(key)] = value;
  return map;
}

static ArgMap ToArgMap(const flutter::EncodableMap& map) {
  ArgMap args;
  for (const auto& [key, value] : map) {
    if (std::holds_alternative<std::string>(key)) args[std::get<std::string>(key)] = value;
  }
  return args;
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
  // A data refresh racing a dismissal must not rebuild the windows the user just closed.
  auto refresh = args.find("refresh");
  if (overlay_windows_.empty() && refresh != args.end() && std::holds_alternative<bool>(refresh->second) &&
      std::get<bool>(refresh->second)) {
    return;
  }
  bool compact = IsCompact(args);
  if (compact && compact_active_ && !overlay_windows_.empty()) {
    last_show_args_ = ToEncodableMap(args);
    RECT rect = CompactRect(overlay_windows_[0].monitor, args);
    HWND hwnd = overlay_windows_[0].window->GetHandle();
    RECT current;
    if (GetWindowRect(hwnd, &current) && !EqualRect(&current, &rect)) {
      overlay_windows_[0].window->SetOverlayRect(rect);
      overlay_windows_[0].window->Show();
    }
    return;
  }
  if (!overlay_windows_.empty() && (compact || compact_active_)) {
    HideOverlay();
  }
  if (compact) {
    ShowCompact(args);
    return;
  }
  if (!overlay_windows_.empty()) {
    // A reminder may be up on the primary monitor only; a break that wants
    // every monitor rebuilds from the warm pool instead of being ignored.
    auto want_all = args.find("showOnAllDisplays");
    bool all_displays = want_all == args.end() || !std::holds_alternative<bool>(want_all->second) ||
                        std::get<bool>(want_all->second);
    if (!all_displays || overlay_windows_.size() >= static_cast<size_t>(GetSystemMetrics(SM_CMONITORS))) {
      return;
    }
    HideOverlay();
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
      if (pool_it->monitor != hMonitor || pool_it->compact) continue;

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

void OverlayWindowManager::ShowCompact(const ArgMap& args) {
  last_show_args_ = ToEncodableMap(args);
  POINT cursor = {};
  GetCursorPos(&cursor);
  HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTOPRIMARY);
  RECT rect = CompactRect(monitor, args);
  compact_active_ = true;

  for (auto it = warm_pool_.begin(); it != warm_pool_.end(); ++it) {
    if (it->monitor != monitor || !it->compact) continue;
    OverlayEntry entry = std::move(*it);
    warm_pool_.erase(it);
    entry.window->SetOverlayRect(rect);
    entry.window->Show();
    overlay_windows_.push_back(std::move(entry));
    UpdateOverlayData(last_show_args_);
    return;
  }

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint("overlayMain");
  auto window = std::make_unique<FlutterWindow>(project);
  window->SetIsOverlay(true);
  window->SetCompact(true);
  if (!window->Create(L"StandupOverlay", Win32Window::Point(rect.left, rect.top),
                      Win32Window::Size(rect.right - rect.left, rect.bottom - rect.top), monitor, WS_POPUP)) {
    compact_active_ = false;
    return;
  }
  window->SetQuitOnClose(false);
  window->ConfigureAsOverlay();
  window->SetOverlayRect(rect);
  window->Show();
  IpcBridgeManager::GetInstance()->RegisterEngine(window->GetEngine());
  overlay_windows_.push_back(OverlayEntry{monitor, std::move(window), true});
}

void OverlayWindowManager::OpenImmersive() {
  if (!compact_active_) return;
  ArgMap args = ToArgMap(last_show_args_);
  args["windowMode"] = flutter::EncodableValue(std::string("immersive"));
  args.erase("refresh");
  bool strict = false;
  auto it = args.find("strictMode");
  if (it != args.end() && std::holds_alternative<bool>(it->second)) strict = std::get<bool>(it->second);
  ShowOverlay(strict, args);
  switched_to_immersive_ = true;
}

void OverlayWindowManager::ApplyModeOverride(ArgMap& args) {
  auto it = args.find("refresh");
  bool refresh = it != args.end() && std::holds_alternative<bool>(it->second) && std::get<bool>(it->second);
  if (!refresh) {
    switched_to_immersive_ = false;
  } else if (switched_to_immersive_ && StringArg(args, "windowMode", "") == "compact") {
    args["windowMode"] = flutter::EncodableValue(std::string("immersive"));
  }
}

void OverlayWindowManager::HideOverlay() {
  switched_to_immersive_ = false;
  if (overlay_windows_.empty()) return;
  for (auto& entry : overlay_windows_) entry.compact = compact_active_;
  compact_active_ = false;

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
  compact_active_ = false;
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
  if (overlay_windows_.empty() || compact_active_) return;

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

  ArgMap args = ToArgMap(last_show_args_);
  args.erase("refresh");

  DestroyAll();
  if (was_active) {
    ShowOverlay(strict, args);
  }
}
