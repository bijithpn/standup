#ifndef OVERLAY_WINDOW_MANAGER_H_
#define OVERLAY_WINDOW_MANAGER_H_

#include <vector>
#include <memory>
#include "flutter_window.h"

class OverlayWindowManager {
 public:
  static OverlayWindowManager* GetInstance();

  void ShowOverlay(bool is_strict_mode, const std::map<std::string, flutter::EncodableValue>& args);
  void HideOverlay();
  void UpdateOverlayData(const flutter::EncodableMap& data);

 private:
  OverlayWindowManager();
  ~OverlayWindowManager();

  static OverlayWindowManager* instance_;
  std::vector<std::unique_ptr<FlutterWindow>> overlay_windows_;
};

#endif  // OVERLAY_WINDOW_MANAGER_H_
