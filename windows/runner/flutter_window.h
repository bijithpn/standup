#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Configure window as full-screen overlay (always on top, no borders)
  void ConfigureAsOverlay();

  // Reset window to normal state
  void ResetToNormal();

  // Set window transparency (0.0 - 1.0)
  void SetWindowTransparency(double opacity);

  // Set window to ignore mouse events (click-through)
  void SetIgnoreMouseEvents(bool ignore);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Store original window style for restoration
  LONG original_style_ = 0;
  LONG original_ex_style_ = 0;
  bool is_overlay_mode_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
