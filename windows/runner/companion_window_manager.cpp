#include "companion_window_manager.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <dwmapi.h>
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

static void ConfigureAsCompanionWindow(HWND hwnd, bool click_through) {
  LONG style = GetWindowLong(hwnd, GWL_STYLE);
  style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
  SetWindowLong(hwnd, GWL_STYLE, style);

  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  exStyle |= WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
  if (click_through) {
    exStyle |= WS_EX_TRANSPARENT;
  } else {
    exStyle &= ~WS_EX_TRANSPARENT;
  }
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);

  SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);

  SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

void CompanionWindowManager::ShowCompanion(const std::string& theme_id,
                                           const std::string& pet_name,
                                           double scale,
                                           bool click_through) {
  if (companion_window_) {
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
  follow_mouse_ = false;

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

  SetWindowPos(hwnd, HWND_TOPMOST,
               mi.rcMonitor.left, mi.rcMonitor.top, w, h,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);

  companion_window_->Show();
  IpcBridgeManager::GetInstance()->RegisterEngine(companion_window_->GetEngine());

  if (companion_window_->GetEngine()) {
    mouse_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        companion_window_->GetEngine()->messenger(),
        "com.breakmate.desktop/companion_data",
        &flutter::StandardMethodCodec::GetInstance());
  }

  SetTimer(hwnd, kMouseTimerId, 16,
      [](HWND, UINT, UINT_PTR, DWORD) {
        CompanionWindowManager::GetInstance()->UpdateMousePosition();
      });

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

static double ToDouble(const flutter::EncodableValue& v, double fallback = 0.0) {
  if (std::holds_alternative<double>(v)) return std::get<double>(v);
  if (std::holds_alternative<int>(v))    return static_cast<double>(std::get<int>(v));
  if (std::holds_alternative<int64_t>(v)) return static_cast<double>(std::get<int64_t>(v));
  return fallback;
}

static std::string ExtractString(const flutter::EncodableValue& v,
                            const std::string& fallback = "") {
  if (std::holds_alternative<std::string>(v)) return std::get<std::string>(v);
  return fallback;
}

static bool ExtractBool(const flutter::EncodableValue& v, bool fallback = false) {
  if (std::holds_alternative<bool>(v)) return std::get<bool>(v);
  return fallback;
}

void CompanionWindowManager::ShowPiP(
    const std::map<std::string, flutter::EncodableValue>& args) {
  double x         = 100.0, y         = 100.0;
  double pip_w     = 280.0, pip_h     = 320.0;
  std::string theme_id = "grey_cat";
  std::string pet_name = "Mochi";
  double scale         = 3.0;
  bool click_through   = false;

  auto it = args.find("x");         if (it != args.end()) x         = ToDouble(it->second, 100.0);
  it = args.find("y");              if (it != args.end()) y         = ToDouble(it->second, 100.0);
  it = args.find("width");          if (it != args.end()) pip_w     = ToDouble(it->second, 280.0);
  it = args.find("height");         if (it != args.end()) pip_h     = ToDouble(it->second, 320.0);
  it = args.find("themeId");        if (it != args.end()) theme_id  = ExtractString(it->second, "grey_cat");
  it = args.find("petName");        if (it != args.end()) pet_name  = ExtractString(it->second, "Mochi");
  it = args.find("scale");          if (it != args.end()) scale     = ToDouble(it->second, 3.0);
  it = args.find("clickThrough");   if (it != args.end()) click_through = ExtractBool(it->second, false);

  const int iX = static_cast<int>(x);
  const int iY = static_cast<int>(y);
  const int iW = static_cast<int>(pip_w);
  const int iH = static_cast<int>(pip_h);

  if (pip_window_) {
    HWND hwnd = pip_window_->GetHandle();
    if (hwnd) {
      SetWindowPos(hwnd, HWND_TOPMOST, iX, iY, iW, iH,
                   SWP_NOACTIVATE | SWP_SHOWWINDOW);
    }
    UpdatePiPParams(args);
    return;
  }

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint("pipMain");

  pip_window_ = std::make_unique<FlutterWindow>(project);

  flutter::EncodableMap settings;
  settings[flutter::EncodableValue("themeId")]      = flutter::EncodableValue(theme_id);
  settings[flutter::EncodableValue("petName")]      = flutter::EncodableValue(pet_name);
  settings[flutter::EncodableValue("scale")]        = flutter::EncodableValue(scale);
  settings[flutter::EncodableValue("clickThrough")] = flutter::EncodableValue(click_through);
  pip_window_->SetInitialSettings(settings);
  pip_window_->SetIsPiP(true);

  Win32Window::Point origin(iX, iY);
  Win32Window::Size  size(iW, iH);

  if (!pip_window_->Create(L"BreakMatePiP", origin, size)) {
    pip_window_ = nullptr;
    return;
  }
  pip_window_->SetQuitOnClose(false);

  HWND hwnd = pip_window_->GetHandle();

  LONG style = GetWindowLong(hwnd, GWL_STYLE);
  style &= ~(WS_CAPTION | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
  style |= WS_THICKFRAME;
  SetWindowLong(hwnd, GWL_STYLE, style);

  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  exStyle |= WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
  if (click_through) {
    exStyle |= WS_EX_TRANSPARENT;
    pip_window_->SetIgnoreMouseEvents(true);
  }
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);

  // Enable transparent background so Flutter's rounded corners blend correctly
  MARGINS margins = {-1, -1, -1, -1};
  DwmExtendFrameIntoClientArea(hwnd, &margins);

  SetWindowPos(hwnd, HWND_TOPMOST, iX, iY, iW, iH,
               SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_FRAMECHANGED);

  pip_window_->Show();
  IpcBridgeManager::GetInstance()->RegisterEngine(pip_window_->GetEngine());

  if (pip_window_->GetEngine()) {
    pip_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        pip_window_->GetEngine()->messenger(),
        "com.breakmate.desktop/pip_data",
        &flutter::StandardMethodCodec::GetInstance());
  }
}

void CompanionWindowManager::HidePiP() {
  if (!pip_window_) return;

  HWND hwnd = pip_window_->GetHandle();
  if (hwnd) {
    KillTimer(hwnd, kPipMouseTimerId);
  }

  pip_channel_.reset();

  if (pip_window_->GetEngine()) {
    IpcBridgeManager::GetInstance()->UnregisterEngine(pip_window_->GetEngine());
  }
  pip_window_->Destroy();
  pip_window_ = nullptr;
}

void CompanionWindowManager::UpdatePiPParams(
    const std::map<std::string, flutter::EncodableValue>& params) {
  if (!pip_window_ || !pip_channel_) return;

  flutter::EncodableMap args;
  for (const auto& [key, value] : params) {
    args[flutter::EncodableValue(key)] = value;
  }
  pip_channel_->InvokeMethod(
      "syncPiPSettings",
      std::make_unique<flutter::EncodableValue>(args));
}
