#include "companion_window_manager.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include "ipc_bridge_manager.h"

CompanionWindowManager* CompanionWindowManager::instance_ = nullptr;

CompanionWindowManager* CompanionWindowManager::GetInstance() {
  if (!instance_) {
    instance_ = new CompanionWindowManager();
  }
  return instance_;
}

CompanionWindowManager::CompanionWindowManager() {}

CompanionWindowManager::~CompanionWindowManager() {
  HideCompanion();
}

// Configures a FlutterWindow's HWND as a transparent, always-on-top,
// click-through companion window (NOT a full-screen overlay).
static void ConfigureAsCompanionWindow(HWND hwnd, bool click_through) {
  // Remove title bar, borders, resize frame
  LONG style = GetWindowLong(hwnd, GWL_STYLE);
  style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
  SetWindowLong(hwnd, GWL_STYLE, style);

  // Layered (per-pixel alpha), toolwindow (no taskbar), topmost
  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  exStyle |= WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
  if (click_through) {
    exStyle |= WS_EX_TRANSPARENT;
  } else {
    exStyle &= ~WS_EX_TRANSPARENT;
  }
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);

  // Per-pixel alpha: use LWA_COLORKEY+LWA_ALPHA together so Flutter's
  // transparent pixels pass through. Full opacity (255) lets Flutter
  // manage alpha via its own rendering.
  SetLayeredWindowAttributes(hwnd, RGB(0, 0, 0), 255, LWA_ALPHA);

  // Always on top, no activation
  SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

void CompanionWindowManager::ShowCompanion(const std::string& theme_id,
                                           const std::string& pet_name,
                                           double scale,
                                           bool click_through) {
  if (companion_window_) {
    // Already showing — just update params
    UpdateParams({
      {"themeId", flutter::EncodableValue(theme_id)},
      {"petName", flutter::EncodableValue(pet_name)},
      {"scale",   flutter::EncodableValue(scale)},
      {"clickThrough", flutter::EncodableValue(click_through)},
    });
    return;
  }

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint("companionMain");

  companion_window_ = std::make_unique<FlutterWindow>(project);

  flutter::EncodableMap settings;
  settings[flutter::EncodableValue("themeId")]     = flutter::EncodableValue(theme_id);
  settings[flutter::EncodableValue("petName")]     = flutter::EncodableValue(pet_name);
  settings[flutter::EncodableValue("scale")]       = flutter::EncodableValue(scale);
  settings[flutter::EncodableValue("clickThrough")] = flutter::EncodableValue(click_through);
  companion_window_->SetInitialSettings(settings);
  click_through_ = click_through;
  follow_mouse_ = false;  // will be set via UpdateParams if enabled

  // Companion lives on the primary monitor — full-screen so the pet can
  // wander freely. The window itself is transparent + click-through so it
  // doesn't block anything below it.
  HMONITOR primary = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO mi = {sizeof(mi)};
  GetMonitorInfo(primary, &mi);

  const int w = mi.rcMonitor.right  - mi.rcMonitor.left;
  const int h = mi.rcMonitor.bottom - mi.rcMonitor.top;

  Win32Window::Point origin(mi.rcMonitor.left, mi.rcMonitor.top);
  Win32Window::Size  size(w, h);

  if (!companion_window_->Create(L"StandupCompanion", origin, size)) {
    companion_window_ = nullptr;
    return;
  }

  companion_window_->SetQuitOnClose(false);
  HWND hwnd = companion_window_->GetHandle();
  ConfigureAsCompanionWindow(hwnd, click_through);

  // Position: full-monitor so the pet can walk anywhere
  SetWindowPos(hwnd, HWND_TOPMOST,
               mi.rcMonitor.left, mi.rcMonitor.top, w, h,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);

  companion_window_->Show();
  IpcBridgeManager::GetInstance()->RegisterEngine(companion_window_->GetEngine());

  // Reuse a single persistent channel object for mouse-tracking pushes
  if (companion_window_->GetEngine()) {
    mouse_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        companion_window_->GetEngine()->messenger(),
        "com.breakmate.desktop/companion_data",
        &flutter::StandardMethodCodec::GetInstance());
  }

  // Poll mouse position at ~60 Hz to drive cursor-following
  SetTimer(hwnd, kMouseTimerId, 16,
      [](HWND, UINT, UINT_PTR, DWORD) {
        CompanionWindowManager::GetInstance()->UpdateMousePosition();
      });

  // Poll monitor changes at 2 Hz
  SetTimer(hwnd, kMonitorTimerId, 500,
      [](HWND, UINT, UINT_PTR, DWORD) {
        CompanionWindowManager::GetInstance()->UpdateMonitorIfNeeded();
      });
}

void CompanionWindowManager::UpdateMousePosition() {
  if (!companion_window_ || !mouse_channel_) return;

  POINT pt;
  if (!GetCursorPos(&pt)) return;

  HWND hwnd = companion_window_->GetHandle();
  RECT wr;
  GetWindowRect(hwnd, &wr);

  const double local_x = static_cast<double>(pt.x - wr.left);
  const double local_y = static_cast<double>(pt.y - wr.top);

  flutter::EncodableMap mouse_follow;
  mouse_follow[flutter::EncodableValue("enabled")] = flutter::EncodableValue(follow_mouse_);
  mouse_follow[flutter::EncodableValue("mouseX")]  = flutter::EncodableValue(local_x);
  mouse_follow[flutter::EncodableValue("mouseY")]  = flutter::EncodableValue(local_y);

  flutter::EncodableMap args;
  args[flutter::EncodableValue("mouseFollow")] = flutter::EncodableValue(mouse_follow);

  mouse_channel_->InvokeMethod(
      "syncCompanionSettings",
      std::make_unique<flutter::EncodableValue>(args));
}

void CompanionWindowManager::UpdateMonitorIfNeeded() {
  if (!companion_window_) return;

  POINT pt;
  if (!GetCursorPos(&pt)) return;

  HMONITOR target = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = {sizeof(mi)};
  if (!GetMonitorInfo(target, &mi)) return;

  HWND hwnd = companion_window_->GetHandle();
  RECT wr;
  GetWindowRect(hwnd, &wr);

  const int new_l = mi.rcMonitor.left;
  const int new_t = mi.rcMonitor.top;
  const int new_w = mi.rcMonitor.right  - mi.rcMonitor.left;
  const int new_h = mi.rcMonitor.bottom - mi.rcMonitor.top;

  if (wr.left != new_l || wr.top != new_t ||
      (wr.right - wr.left) != new_w || (wr.bottom - wr.top) != new_h) {
    SetWindowPos(hwnd, HWND_TOPMOST,
                 new_l, new_t, new_w, new_h,
                 SWP_NOACTIVATE);
  }
}

void CompanionWindowManager::HideCompanion() {
  if (!companion_window_) return;

  HWND hwnd = companion_window_->GetHandle();
  if (hwnd) {
    KillTimer(hwnd, kMouseTimerId);
    KillTimer(hwnd, kMonitorTimerId);
  }

  mouse_channel_.reset();

  if (companion_window_->GetEngine()) {
    IpcBridgeManager::GetInstance()->UnregisterEngine(companion_window_->GetEngine());
  }
  companion_window_->Destroy();
  companion_window_ = nullptr;
}

void CompanionWindowManager::UpdateParams(
    const std::map<std::string, flutter::EncodableValue>& params) {
  if (!companion_window_) return;

  auto it = params.find("clickThrough");
  if (it != params.end() && std::holds_alternative<bool>(it->second)) {
    const bool ct = std::get<bool>(it->second);
    if (ct != click_through_) {
      click_through_ = ct;
      HWND hwnd = companion_window_->GetHandle();
      LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
      if (ct) exStyle |= WS_EX_TRANSPARENT;
      else     exStyle &= ~WS_EX_TRANSPARENT;
      SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);
    }
  }

  auto it_follow = params.find("followMouse");
  if (it_follow != params.end() && std::holds_alternative<bool>(it_follow->second)) {
    follow_mouse_ = std::get<bool>(it_follow->second);
  }

  if (!mouse_channel_) return;

  flutter::EncodableMap args;
  for (const auto& [key, value] : params) {
    args[flutter::EncodableValue(key)] = value;
  }
  mouse_channel_->InvokeMethod(
      "syncCompanionSettings",
      std::make_unique<flutter::EncodableValue>(args));
}
