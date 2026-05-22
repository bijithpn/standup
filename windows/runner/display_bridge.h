#ifndef RUNNER_DISPLAY_BRIDGE_H_
#define RUNNER_DISPLAY_BRIDGE_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <vector>

class DisplayStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  DisplayStreamHandler() = default;
  virtual ~DisplayStreamHandler() = default;

  void SendUpdate() {
    if (event_sink_) {
      flutter::EncodableMap data;
      data[flutter::EncodableValue("type")] = flutter::EncodableValue("display_changed");
      event_sink_->Success(flutter::EncodableValue(data));
    }
  }

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    event_sink_ = std::move(events);
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override {
    event_sink_ = nullptr;
    return nullptr;
  }

 private:
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};

void RegisterDisplayBridge(flutter::FlutterEngine* engine, DisplayStreamHandler** handler_out);

#endif  // RUNNER_DISPLAY_BRIDGE_H_
