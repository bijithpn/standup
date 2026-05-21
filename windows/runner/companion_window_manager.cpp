#include "companion_window_manager.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

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

  Win32Window::Point origin(100, 100);
  Win32Window::Size size(200, 200);
  
  if (!companion_window_->Create(L"StandupCompanion", origin, size)) {
    companion_window_ = nullptr;
    return;
  }

  companion_window_->SetQuitOnClose(false);
  companion_window_->ConfigureAsOverlay();
  companion_window_->Show();
}


void CompanionWindowManager::HideCompanion() {
  if (companion_window_) {
    companion_window_->Destroy();
    companion_window_ = nullptr;
  }
}

void CompanionWindowManager::UpdateParams(const std::map<std::string, flutter::EncodableValue>& params) {
  if (!companion_window_) return;
  
  auto engine = companion_window_->GetEngine();
  if (engine) {
      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), "com.breakmate.macos/companion_data",
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
