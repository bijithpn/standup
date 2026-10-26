#ifndef RUNNER_BRIDGE_UTIL_H_
#define RUNNER_BRIDGE_UTIL_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <functional>
#include <string>

// Small helpers shared by the Linux bridges. They mirror what the macOS
// (Swift) and Windows (C++) runners do for the same channels, so the Dart side
// can treat all three desktops alike.
namespace bm {

// ---- FlValue readers -------------------------------------------------------

inline FlValue* Lookup(FlValue* map, const char* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) return nullptr;
  return fl_value_lookup_string(map, key);
}

inline double Num(FlValue* map, const char* key, double fallback) {
  FlValue* v = Lookup(map, key);
  if (v == nullptr) return fallback;
  if (fl_value_get_type(v) == FL_VALUE_TYPE_FLOAT) return fl_value_get_float(v);
  if (fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    return static_cast<double>(fl_value_get_int(v));
  }
  return fallback;
}

inline bool GetBool(FlValue* map, const char* key, bool fallback) {
  FlValue* v = Lookup(map, key);
  if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
    return fl_value_get_bool(v);
  }
  return fallback;
}

inline std::string Str(FlValue* map, const char* key, const std::string& fallback = "") {
  FlValue* v = Lookup(map, key);
  if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    return fl_value_get_string(v);
  }
  return fallback;
}

inline bool Has(FlValue* map, const char* key) { return Lookup(map, key) != nullptr; }

// ---- FlValue builders ------------------------------------------------------

inline void SetNum(FlValue* map, const char* key, double v) {
  fl_value_set_string_take(map, key, fl_value_new_float(v));
}
inline void SetBool(FlValue* map, const char* key, bool v) {
  fl_value_set_string_take(map, key, fl_value_new_bool(v));
}
inline void SetStr(FlValue* map, const char* key, const std::string& v) {
  fl_value_set_string_take(map, key, fl_value_new_string(v.c_str()));
}

// ---- Method responses ------------------------------------------------------

inline void Ok(FlMethodCall* call, FlValue* value = nullptr) {
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_success(call, value, &error);
}

inline void Fail(FlMethodCall* call, const char* code, const char* message) {
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_error(call, code, message, nullptr, &error);
}

inline void NotImplemented(FlMethodCall* call) {
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond_not_implemented(call, &error);
}

// ---- Channels --------------------------------------------------------------

using MethodHandler = std::function<void(FlMethodCall*)>;

// Creates a method channel whose handler lives as long as the channel. The
// caller owns the returned reference (g_object_unref when done).
inline FlMethodChannel* NewMethodChannel(FlBinaryMessenger* messenger, const char* name,
                                         MethodHandler handler) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(messenger, name, FL_METHOD_CODEC(codec));
  auto* boxed = new MethodHandler(std::move(handler));
  fl_method_channel_set_method_call_handler(
      channel,
      [](FlMethodChannel*, FlMethodCall* call, gpointer data) {
        (*static_cast<MethodHandler*>(data))(call);
      },
      boxed, [](gpointer data) { delete static_cast<MethodHandler*>(data); });
  return channel;
}

// Calls into Dart and ignores the reply.
inline void Invoke(FlMethodChannel* channel, const char* method, FlValue* args) {
  if (channel == nullptr) return;
  fl_method_channel_invoke_method(channel, method, args, nullptr, nullptr, nullptr);
}

// An event channel that only forwards values while Dart is listening.
class EventStream {
 public:
  using ListenCallback = std::function<void()>;

  EventStream(FlBinaryMessenger* messenger, const char* name, ListenCallback on_listen = nullptr)
      : on_listen_(std::move(on_listen)) {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    channel_ = fl_event_channel_new(messenger, name, FL_METHOD_CODEC(codec));
    fl_event_channel_set_stream_handlers(
        channel_,
        [](FlEventChannel*, FlValue*, gpointer data) -> FlMethodErrorResponse* {
          auto* self = static_cast<EventStream*>(data);
          self->listening_ = true;
          if (self->on_listen_) self->on_listen_();
          return nullptr;
        },
        [](FlEventChannel*, FlValue*, gpointer data) -> FlMethodErrorResponse* {
          static_cast<EventStream*>(data)->listening_ = false;
          return nullptr;
        },
        this, nullptr);
  }

  ~EventStream() {
    if (channel_ != nullptr) g_object_unref(channel_);
  }

  EventStream(const EventStream&) = delete;
  EventStream& operator=(const EventStream&) = delete;

  bool listening() const { return listening_; }

  // Takes ownership of |value|.
  void Send(FlValue* value) {
    g_autoptr(FlValue) owned = value;
    if (!listening_) return;
    g_autoptr(GError) error = nullptr;
    fl_event_channel_send(channel_, owned, nullptr, &error);
  }

 private:
  FlEventChannel* channel_ = nullptr;
  bool listening_ = false;
  ListenCallback on_listen_;
};

}  // namespace bm

#endif  // RUNNER_BRIDGE_UTIL_H_
