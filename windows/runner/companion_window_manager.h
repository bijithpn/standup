#ifndef RUNNER_COMPANION_WINDOW_MANAGER_H_
#define RUNNER_COMPANION_WINDOW_MANAGER_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
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

  void ShowCompanion(const std::string& theme_id, const std::string& pet_name,
                     double scale, bool click_through);
  void HideCompanion();
  void UpdateParams(const std::map<std::string, flutter::EncodableValue>& params);

  // PiP (Picture-in-Picture) window — small, draggable, always-on-top.
  // args: x, y, width, height, themeId, petName, scale, clickThrough
  void ShowPiP(const std::map<std::string, flutter::EncodableValue>& args);
  void HidePiP();
  void UpdatePiPParams(const std::map<std::string, flutter::EncodableValue>& params);

  // Called by the mouse-poll timer (public so the static lambda can reach it)
  void UpdateMousePosition();
  // Called by the monitor-change timer
  void UpdateMonitorIfNeeded();

 private:
  static CompanionWindowManager* instance_;

  std::unique_ptr<FlutterWindow> companion_window_;
  // Persistent channel — avoids allocating a new one every 16 ms
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> mouse_channel_;
  bool click_through_ = true;
  bool follow_mouse_ = false;

  // PiP window
  std::unique_ptr<FlutterWindow> pip_window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> pip_channel_;

  static constexpr UINT_PTR kMouseTimerId   = 2;
  static constexpr UINT_PTR kMonitorTimerId = 3;
  static constexpr UINT_PTR kPipMouseTimerId = 4;
};

#endif  // RUNNER_COMPANION_WINDOW_MANAGER_H_
