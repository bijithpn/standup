#include "ipc_bridge_manager.h"
#include <iostream>
#include <algorithm>

IpcBridgeManager* IpcBridgeManager::instance_ = nullptr;

IpcBridgeManager* IpcBridgeManager::GetInstance() {
  if (!instance_) {
    instance_ = new IpcBridgeManager();
  }
  return instance_;
}

IpcBridgeManager::IpcBridgeManager() {}

IpcBridgeManager::~IpcBridgeManager() {}

void IpcBridgeManager::RegisterEngine(flutter::FlutterEngine* engine) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  // Only register if not already registered
  if (std::find(engines_.begin(), engines_.end(), engine) == engines_.end()) {
    engines_.push_back(engine);

    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        engine->messenger(), "com.breakmate/ipc",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [this, engine](const flutter::MethodCall<flutter::EncodableValue>& call,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          if (call.method_name() == "sendEvent") {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (args) {
              auto event_it = args->find(flutter::EncodableValue("event"));
              auto data_it = args->find(flutter::EncodableValue("data"));
              
              if (event_it != args->end() && std::holds_alternative<std::string>(event_it->second)) {
                std::string event_name = std::get<std::string>(event_it->second);
                flutter::EncodableValue data;
                if (data_it != args->end()) {
                  data = data_it->second;
                }
                
                // Broadcast to other engines
                SendEvent(event_name, data, engine);
              }
            }
            result->Success();
          } else {
            result->NotImplemented();
          }
        });

    channels_.push_back(std::move(channel));
  }
}

void IpcBridgeManager::UnregisterEngine(flutter::FlutterEngine* engine) {
  std::lock_guard<std::mutex> lock(mutex_);
  engines_.erase(std::remove(engines_.begin(), engines_.end(), engine), engines_.end());
  
  // It's acceptable to leak the unique_ptrs in channels_ as the app shuts down 
  // or we can remove them if we track them by engine, but for simplicity here we just leave them.
}

void IpcBridgeManager::SendEvent(const std::string& event_name, const flutter::EncodableValue& data, flutter::FlutterEngine* sender_engine) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  for (auto* engine : engines_) {
    if (engine != sender_engine) {
      flutter::EncodableMap args;
      args[flutter::EncodableValue("event")] = flutter::EncodableValue(event_name);
      args[flutter::EncodableValue("data")] = data;

      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), "com.breakmate/ipc",
          &flutter::StandardMethodCodec::GetInstance());
      channel->InvokeMethod("onEvent", std::make_unique<flutter::EncodableValue>(args));
    }
  }
}
