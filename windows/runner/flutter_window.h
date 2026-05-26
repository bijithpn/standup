#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

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

  // Expose the engine for external bridge registration
  flutter::FlutterEngine* GetEngine() {
    return flutter_controller_ ? flutter_controller_->engine() : nullptr;
  }

  // Set initial settings for companion
  void SetInitialSettings(const flutter::EncodableMap& settings) {
    initial_settings_ = settings;
    is_companion_ = true;
  }

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Sets up the bridge channel for platform-specific features
  void SetupBridge();

  // Sets up event channels for streams
  void SetupEventChannels();

  // Sets up the window bridge (com.breakmate/window)
  void SetupWindowBridge();

  // Sets up the companion data bridge (if is_companion_)
  void SetupCompanionBridge();

  // Sets up the overlay bridge (com.breakmate/overlay)
  void SetupOverlayBridge();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channels
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> bridge_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> window_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> companion_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> overlay_channel_;

  // Event channels for streams
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> focus_mode_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> meeting_detection_channel_;

  // Companion state
  bool is_companion_ = false;
  flutter::EncodableMap initial_settings_;

  LONG original_style_ = 0;
  LONG original_ex_style_ = 0;
  bool is_overlay_mode_ = false;

  static HHOOK keyboard_hook_;
  static LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
