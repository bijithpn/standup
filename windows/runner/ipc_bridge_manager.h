#ifndef IPC_BRIDGE_MANAGER_H_
#define IPC_BRIDGE_MANAGER_H_

#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <mutex>
#include <map>

class IpcBridgeManager {
 public:
  static IpcBridgeManager* GetInstance();

  void RegisterEngine(flutter::FlutterEngine* engine);
  void UnregisterEngine(flutter::FlutterEngine* engine);
  void SendEvent(const std::string& event_name, const flutter::EncodableValue& data, flutter::FlutterEngine* sender_engine);

 private:
  IpcBridgeManager();
  ~IpcBridgeManager();

  static IpcBridgeManager* instance_;
  std::mutex mutex_;
  std::map<flutter::FlutterEngine*, std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>> engines_map_;
};

#endif  // IPC_BRIDGE_MANAGER_H_
