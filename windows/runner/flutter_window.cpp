#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// Configure window as full-screen overlay
void FlutterWindow::ConfigureAsOverlay() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  // Store original styles for restoration
  original_style_ = GetWindowLong(hwnd, GWL_STYLE);
  original_ex_style_ = GetWindowLong(hwnd, GWL_EXSTYLE);

  // Remove window borders and title bar (WS_CAPTION = WS_BORDER | WS_DLGFRAME)
  LONG style = GetWindowLong(hwnd, GWL_STYLE);
  style &= ~WS_CAPTION;      // Remove title bar
  style &= ~WS_THICKFRAME;   // Remove resize border
  style &= ~WS_MINIMIZEBOX;  // Remove minimize button
  style &= ~WS_MAXIMIZEBOX;  // Remove maximize button
  SetWindowLong(hwnd, GWL_STYLE, style);

  // Add layered and topmost extended styles
  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  exStyle |= WS_EX_LAYERED;      // Enable transparency
  exStyle |= WS_EX_TOOLWINDOW;   // Hide from taskbar
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);

  // Set window as topmost (above all other windows)
  SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  // Get screen dimensions for full-screen
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitorInfo = {};
  monitorInfo.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(monitor, &monitorInfo);

  // Set to full-screen
  SetWindowPos(hwnd, HWND_TOPMOST,
               monitorInfo.rcMonitor.left,
               monitorInfo.rcMonitor.top,
               monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left,
               monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top,
               SWP_NOACTIVATE);

  is_overlay_mode_ = true;
}

// Reset window to normal state
void FlutterWindow::ResetToNormal() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  // Restore original styles
  SetWindowLong(hwnd, GWL_STYLE, original_style_);
  SetWindowLong(hwnd, GWL_EXSTYLE, original_ex_style_);

  // Remove topmost status
  SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  is_overlay_mode_ = false;
}

// Set window transparency (opacity 0.0 - 1.0)
void FlutterWindow::SetWindowTransparency(double opacity) {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  // Clamp opacity to valid range
  opacity = opacity < 0.0 ? 0.0 : (opacity > 1.0 ? 1.0 : opacity);
  
  // Set layered window attributes (alpha blending)
  BYTE alpha = static_cast<BYTE>(opacity * 255);
  SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_ALPHA);
}

// Set window to ignore mouse events (click-through)
void FlutterWindow::SetIgnoreMouseEvents(bool ignore) {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
  if (ignore) {
    exStyle |= WS_EX_TRANSPARENT;  // Mouse events pass through
  } else {
    exStyle &= ~WS_EX_TRANSPARENT; // Normal mouse interaction
  }
  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
