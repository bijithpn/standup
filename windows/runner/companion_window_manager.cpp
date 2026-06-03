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

void CompanionWindowManager::ShowCompanion(const std::string& theme_id, const std::string& pet_name, double scale, bool click_through) {
  if (companion_window_) {
    // Already showing, maybe update?
    return;
  }

  flutter::DartProject project(L"data");
  // Use the correct API to set the Dart entrypoint function name
  project.set_dart_entrypoint("companionMain");

  companion_window_ = std::make_unique<FlutterWindow>(project);
  
  flutter::EncodableMap settings;
  settings[flutter::EncodableValue("themeId")] = flutter::EncodableValue(theme_id);
  settings[flutter::EncodableValue("petName")] = flutter::EncodableValue(pet_name);
  settings[flutter::EncodableValue("scale")] = flutter::EncodableValue(scale);
  settings[flutter::EncodableValue("clickThrough")] = flutter::EncodableValue(click_through);
  
  // Mark as companion and store initial settings (accessed via getInitialSettings channel)
  companion_window_->SetInitialSettings(settings);

  // Get primary monitor size for initial window
  int screen_width = GetSystemMetrics(SM_CXSCREEN);
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  Win32Window::Point origin(0, 0);
  Win32Window::Size size(screen_width, screen_height);
  
  if (!companion_window_->Create(L"StandupCompanion", origin, size)) {
    companion_window_ = nullptr;
    return;
  }

  companion_window_->SetQuitOnClose(false);
  companion_window_->ConfigureAsOverlay();
  companion_window_->Show();
  
  IpcBridgeManager::GetInstance()->RegisterEngine(companion_window_->GetEngine());

  // Set a timer to track mouse position for cursor following
  SetTimer(companion_window_->GetHandle(), 2, 16, [](HWND hwnd, UINT msg, UINT_PTR id, DWORD time) {
      CompanionWindowManager::GetInstance()->UpdateMousePosition();
  });
}

void CompanionWindowManager::UpdateMousePosition() {
    if (!companion_window_) return;

    POINT mouse_pos;
    if (GetCursorPos(&mouse_pos)) {
        // Find which monitor the mouse is on
        HMONITOR hMonitor = MonitorFromPoint(mouse_pos, MONITOR_DEFAULTTONEAREST);
        MONITORINFO mi = { sizeof(mi) };
        if (GetMonitorInfo(hMonitor, &mi)) {
            // Check if we need to move the window to a different monitor
            RECT current_rect;
            GetWindowRect(companion_window_->GetHandle(), &current_rect);

            if (current_rect.left != mi.rcMonitor.left || current_rect.top != mi.rcMonitor.top ||
                (current_rect.right - current_rect.left) != (mi.rcMonitor.right - mi.rcMonitor.left)) {
                
                SetWindowPos(companion_window_->GetHandle(), HWND_TOPMOST,
                    mi.rcMonitor.left, mi.rcMonitor.top,
                    mi.rcMonitor.right - mi.rcMonitor.left,
                    mi.rcMonitor.bottom - mi.rcMonitor.top,
                    SWP_NOACTIVATE | SWP_SHOWWINDOW);
            }

            // Calculate local coordinates relative to the monitor
            double local_x = static_cast<double>(mouse_pos.x - mi.rcMonitor.left);
            double local_y = static_cast<double>(mouse_pos.y - mi.rcMonitor.top);

            auto engine = companion_window_->GetEngine();
            if (engine) {
                auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                    engine->messenger(), "com.breakmate.desktop/companion_data",
                    &flutter::StandardMethodCodec::GetInstance());

                flutter::EncodableMap mouse_follow;
                mouse_follow[flutter::EncodableValue("enabled")] = flutter::EncodableValue(true);
                mouse_follow[flutter::EncodableValue("mouseX")] = flutter::EncodableValue(local_x);
                mouse_follow[flutter::EncodableValue("mouseY")] = flutter::EncodableValue(local_y);

                flutter::EncodableMap args;
                args[flutter::EncodableValue("mouseFollow")] = flutter::EncodableValue(mouse_follow);

                channel->InvokeMethod("syncCompanionSettings", std::make_unique<flutter::EncodableValue>(args));
            }
        }
    }
}

void CompanionWindowManager::HideCompanion() {
  if (companion_window_) {
    KillTimer(companion_window_->GetHandle(), 2);
    if (companion_window_->GetEngine()) {
      IpcBridgeManager::GetInstance()->UnregisterEngine(companion_window_->GetEngine());
    }
    companion_window_->Destroy();
    companion_window_ = nullptr;
  }
}

void CompanionWindowManager::UpdateParams(const std::map<std::string, flutter::EncodableValue>& params) {
  if (!companion_window_) return;
  
  auto engine = companion_window_->GetEngine();
  if (engine) {
      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), "com.breakmate.desktop/companion_data",
          &flutter::StandardMethodCodec::GetInstance());
      
      flutter::EncodableMap args;
      for (const auto& [key, value] : params) {
          args[flutter::EncodableValue(key)] = value;
      }
      
      channel->InvokeMethod("syncCompanionSettings", std::make_unique<flutter::EncodableValue>(args));
      
      // Also update native window properties if needed
      auto it_ignore = params.find("clickThrough");
      if (it_ignore != params.end()) {
          companion_window_->SetIgnoreMouseEvents(std::get<bool>(it_ignore->second));
      }
  }
}
