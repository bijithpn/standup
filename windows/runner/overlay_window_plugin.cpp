#include "overlay_window_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <sstream>

#include "flutter_window.h"
#include "win32_window.h"

namespace {

class OverlayWindowPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  OverlayWindowPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~OverlayWindowPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* registrar_;
};

// static
void OverlayWindowPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.breakmate/overlay_window",
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

  // Get the Flutter view's native HWND
  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  if (!hwnd) {
    result->Error("Window Error", "Could not get window handle");
    return;
  }

  // Retrieve the FlutterWindow pointer stored as GWLP_USERDATA
  auto* flutter_window = reinterpret_cast<FlutterWindow*>(
      ::GetWindowLongPtr(hwnd, GWLP_USERDATA));

  if (method_name == "configureAsOverlay") {
    if (flutter_window) {
      flutter_window->ConfigureAsOverlay();
      result->Success();
    } else {
      result->Error("Cast Error", "Could not get FlutterWindow pointer");
    }
  } else if (method_name == "resetToNormal") {
    if (flutter_window) {
      flutter_window->ResetToNormal();
      result->Success();
    } else {
      result->Error("Cast Error", "Could not get FlutterWindow pointer");
    }
  } else if (method_name == "setTransparency") {
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
    if (flutter_window) {
      flutter_window->SetWindowTransparency(opacity);
      result->Success();
    } else {
      result->Error("Cast Error", "Could not get FlutterWindow pointer");
    }
  } else if (method_name == "setIgnoreMouseEvents") {
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
    if (flutter_window) {
      flutter_window->SetIgnoreMouseEvents(ignore);
      result->Success();
    } else {
      result->Error("Cast Error", "Could not get FlutterWindow pointer");
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace

// Free function wrapper — called from FlutterWindow::OnCreate() via the header.
void RegisterOverlayWindowPlugin(flutter::PluginRegistry* registry) {
  OverlayWindowPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(
              registry->GetRegistrarForPlugin("OverlayWindowPlugin")));
}
