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
  
  if (engines_map_.find(engine) == engines_map_.end()) {
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
                
                // Broadcast to other engines; the sender has already handled
                // its own state update.
                SendEvent(event_name, data, engine);
              }
            }
            result->Success();
          } else {
            result->NotImplemented();
          }
        });

    engines_map_[engine] = std::move(channel);
  }
}

void IpcBridgeManager::UnregisterEngine(flutter::FlutterEngine* engine) {
  std::lock_guard<std::mutex> lock(mutex_);
  engines_map_.erase(engine);
}

void IpcBridgeManager::SendEvent(const std::string& event_name, const flutter::EncodableValue& data, flutter::FlutterEngine* sender_engine) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  for (const auto& [engine, channel] : engines_map_) {
    if (engine != sender_engine) {
      // Reuse the channel registered with the engine. Creating a fresh channel
      // for every pet tap added allocation and messenger churn on the UI thread.
      channel->InvokeMethod(
          event_name, std::make_unique<flutter::EncodableValue>(data));
    }
  }
}
