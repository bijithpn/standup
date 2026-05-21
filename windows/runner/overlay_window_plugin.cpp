#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <sstream>

#include "flutter_window.h"

namespace {

class OverlayWindowPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  OverlayWindowPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~OverlayWindowPlugin();

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* registrar_;
};

// static
void OverlayWindowPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.standup/overlay_window",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<OverlayWindowPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

OverlayWindowPlugin::OverlayWindowPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

OverlayWindowPlugin::~OverlayWindowPlugin() {}

void OverlayWindowPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const auto& method_name = method_call.method_name();

  // Get the main Flutter window handle
  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  if (!hwnd) {
    result->Error("Window Error", "Could not get window handle");
    return;
  }

  if (method_name == "configureAsOverlay") {
    // Get the FlutterWindow from the registrar
    auto* win32_window = reinterpret_cast<Win32Window*>(::GetWindowLongPtr(hwnd, GWLP_USERDATA));
    auto* flutter_window = static_cast<FlutterWindow*>(win32_window);
    if (flutter_window) {
      flutter_window->ConfigureAsOverlay();
      result->Success();
    } else {
      result->Error("Cast Error", "Could not cast to FlutterWindow");
    }
  } 
  else if (method_name == "resetToNormal") {
    auto* win32_window = reinterpret_cast<Win32Window*>(::GetWindowLongPtr(hwnd, GWLP_USERDATA));
    auto* flutter_window = static_cast<FlutterWindow*>(win32_window);
    if (flutter_window) {
      flutter_window->ResetToNormal();
      result->Success();
    } else {
      result->Error("Cast Error", "Could not cast to FlutterWindow");
    }
  }
  else if (method_name == "setTransparency") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("Argument Error", "Invalid arguments");
      return;
    }
    
    auto opacity_it = args->find(flutter::EncodableValue("opacity"));
    if (opacity_it == args->end()) {
      result->Error("Argument Error", "Missing opacity argument");
      return;
    }
    
    double opacity = std::get<double>(opacity_it->second);
    auto* win32_window = reinterpret_cast<Win32Window*>(::GetWindowLongPtr(hwnd, GWLP_USERDATA));
    auto* flutter_window = static_cast<FlutterWindow*>(win32_window);
    if (flutter_window) {
      flutter_window->SetWindowTransparency(opacity);
      result->Success();
    } else {
      result->Error("Cast Error", "Could not cast to FlutterWindow");
    }
  }
  else if (method_name == "setIgnoreMouseEvents") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("Argument Error", "Invalid arguments");
      return;
    }
    
    auto ignore_it = args->find(flutter::EncodableValue("ignore"));
    if (ignore_it == args->end()) {
      result->Error("Argument Error", "Missing ignore argument");
      return;
    }
    
    bool ignore = std::get<bool>(ignore_it->second);
    auto* win32_window = reinterpret_cast<Win32Window*>(::GetWindowLongPtr(hwnd, GWLP_USERDATA));
    auto* flutter_window = static_cast<FlutterWindow*>(win32_window);
    if (flutter_window) {
      flutter_window->SetIgnoreMouseEvents(ignore);
      result->Success();
    } else {
      result->Error("Cast Error", "Could not cast to FlutterWindow");
    }
  }
  else {
    result->NotImplemented();
  }
}

}  // namespace

void OverlayWindowPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  OverlayWindowPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
