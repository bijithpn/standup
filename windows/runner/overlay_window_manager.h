#ifndef OVERLAY_WINDOW_MANAGER_H_
#define OVERLAY_WINDOW_MANAGER_H_

#include <vector>
#include <memory>
#include <map>
#include <flutter/encodable_value.h>
#include "flutter_window.h"

class OverlayWindowManager {
 public:
  static OverlayWindowManager* GetInstance();

  void ShowOverlay(bool is_strict_mode, const std::map<std::string, flutter::EncodableValue>& args);
  void HideOverlay();
  void UpdateOverlayData(const flutter::EncodableMap& data);
  // Invoked from the low-level keyboard hook when Escape is pressed so that
  // the overlay can be dismissed even without window focus (SWP_NOACTIVATE).
  void HandleEscapeKey();
  void OnDisplayChange();
  flutter::EncodableMap GetLastShowArgs() const { return last_show_args_; }

 private:
  OverlayWindowManager();
  ~OverlayWindowManager();

  static OverlayWindowManager* instance_;
  std::vector<std::unique_ptr<FlutterWindow>> overlay_windows_;
  flutter::EncodableMap last_show_args_;
};

#endif  // OVERLAY_WINDOW_MANAGER_H_
