#ifndef OVERLAY_WINDOW_MANAGER_H_
#define OVERLAY_WINDOW_MANAGER_H_

#include <vector>
#include <memory>
#include <map>
#include <windows.h>
#include <flutter/encodable_value.h>
#include "flutter_window.h"

class OverlayWindowManager {
 public:
  static OverlayWindowManager* GetInstance();

  void ShowOverlay(bool is_strict_mode, const std::map<std::string, flutter::EncodableValue>& args);
  void HideOverlay();
  // Fully tears down every active AND warm-pooled window/engine — call only
  // when their window frames/DPI are stale (display configuration changed)
  // or the app is quitting. Everyday hide/show should never reach this;
  // that's the whole point of the warm pool (see HideOverlay).
  void DestroyAll();
  void UpdateOverlayData(const flutter::EncodableMap& data);
  // Invoked from the low-level keyboard hook when Escape is pressed so that
  // the overlay can be dismissed even without window focus (SWP_NOACTIVATE).
  void HandleEscapeKey();
  void OnDisplayChange();
  flutter::EncodableMap GetLastShowArgs() const { return last_show_args_; }

  struct OverlayEntry {
    HMONITOR monitor;
    std::unique_ptr<FlutterWindow> window;
  };

 private:
  OverlayWindowManager();
  ~OverlayWindowManager();

  static OverlayWindowManager* instance_;
  std::vector<OverlayEntry> overlay_windows_;
  // Hidden-but-alive entries kept ready for instant reuse. Spinning up a
  // fresh FlutterWindow/engine per show (cold engine start) is the
  // dominant cost of "why does Preview take seconds to appear" — after
  // the first show, later shows on the same monitor set reuse an
  // already-warm engine instead of paying that cost again.
  std::vector<OverlayEntry> warm_pool_;
  flutter::EncodableMap last_show_args_;

  void DestroyEntries(std::vector<OverlayEntry>& entries);
};

#endif  // OVERLAY_WINDOW_MANAGER_H_
