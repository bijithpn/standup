#ifndef RUNNER_COMPANION_WINDOW_MANAGER_H_
#define RUNNER_COMPANION_WINDOW_MANAGER_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <memory>
#include <string>
#include <map>

#include "flutter_window.h"

class CompanionWindowManager {
 public:
  static CompanionWindowManager* GetInstance();

  CompanionWindowManager();
  virtual ~CompanionWindowManager();

  void ShowCompanion(const std::string& theme_id, const std::string& pet_name, double scale, bool click_through);
  void HideCompanion();
  void UpdateParams(const std::map<std::string, flutter::EncodableValue>& params);

 private:
  static CompanionWindowManager* instance_;

  std::unique_ptr<FlutterWindow> companion_window_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};

#endif  // RUNNER_COMPANION_WINDOW_MANAGER_H_
