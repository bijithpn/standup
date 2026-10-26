#include "native_enhancements_bridge.h"

#include <windows.h>
#include <shellapi.h>

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <cstdlib>
#include <cwctype>
#include <memory>
#include <string>
#include <vector>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr ULONGLONG kMicGraceMs = 20000;     // survives mute toggles, as on macOS
constexpr ULONGLONG kCameraGraceMs = 15000;
constexpr UINT kPollMs = 2000;

const wchar_t kConsentRoot[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\";

std::wstring SelfExeName() {
  wchar_t path[MAX_PATH];
  DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring full(path, n);
  size_t slash = full.find_last_of(L"\\/");
  std::wstring name = slash == std::wstring::npos ? full : full.substr(slash + 1);
  for (auto& c : name) c = (wchar_t)towlower(c);
  return name;
}

// A capability (microphone / webcam) is in use when some app's consent entry
// has a start time but LastUsedTimeStop is still 0.
bool IsAppUsingCapability(HKEY root, const std::wstring& path, const std::wstring& self) {
  HKEY key;
  if (RegOpenKeyExW(root, path.c_str(), 0, KEY_READ, &key) != ERROR_SUCCESS) return false;

  bool active = false;
  wchar_t name[512];
  for (DWORD i = 0;; ++i) {
    DWORD len = _countof(name);
    if (RegEnumKeyExW(key, i, name, &len, nullptr, nullptr, nullptr, nullptr) != ERROR_SUCCESS) {
      break;
    }
    std::wstring sub(name, len);
    if (sub == L"NonPackaged") continue;  // enumerated separately by the caller

    std::wstring lowered = sub;
    for (auto& c : lowered) c = (wchar_t)towlower(c);
    if (lowered.find(self) != std::wstring::npos) continue;  // ignore ourselves

    HKEY app;
    if (RegOpenKeyExW(key, name, 0, KEY_READ, &app) != ERROR_SUCCESS) continue;
    ULONGLONG start = 0, stop = 0;
    DWORD size = sizeof(start);
    RegQueryValueExW(app, L"LastUsedTimeStart", nullptr, nullptr, reinterpret_cast<BYTE*>(&start),
                     &size);
    size = sizeof(stop);
    RegQueryValueExW(app, L"LastUsedTimeStop", nullptr, nullptr, reinterpret_cast<BYTE*>(&stop),
                     &size);
    RegCloseKey(app);
    if (start != 0 && stop == 0) {
      active = true;
      break;
    }
  }
  RegCloseKey(key);
  return active;
}

bool IsCapabilityActive(const wchar_t* capability, const std::wstring& self) {
  std::wstring base = std::wstring(kConsentRoot) + capability;
  return IsAppUsingCapability(HKEY_CURRENT_USER, base, self) ||
         IsAppUsingCapability(HKEY_CURRENT_USER, base + L"\\NonPackaged", self);
}

class SmartDetector {
 public:
  explicit SmartDetector(flutter::FlutterEngine* engine) {
    self_ = SelfExeName();
    channel_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
        engine->messenger(), "com.breakmate/smart_detection_events",
        &flutter::StandardMethodCodec::GetInstance());

    auto handler = std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
        [this](const EncodableValue*, std::unique_ptr<flutter::EventSink<EncodableValue>>&& sink)
            -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
          sink_ = std::move(sink);
          Evaluate();
          Push();
          return nullptr;
        },
        [this](const EncodableValue*)
            -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
          sink_ = nullptr;
          return nullptr;
        });
    channel_->SetStreamHandler(std::move(handler));

    timer_ = SetTimer(nullptr, 0, kPollMs, &SmartDetector::OnTimer);
    instance_ = this;
  }

 private:
  static void CALLBACK OnTimer(HWND, UINT, UINT_PTR, DWORD) {
    if (instance_) {
      instance_->Evaluate();
    }
  }

  // Latches "active" immediately and only drops it once the grace period has
  // elapsed with no activity.
  static bool Latch(bool active_now, ULONGLONG grace_ms, bool& current, ULONGLONG& last_seen) {
    ULONGLONG now = GetTickCount64();
    if (active_now) {
      last_seen = now;
      if (!current) {
        current = true;
        return true;
      }
    } else if (current && now - last_seen >= grace_ms) {
      current = false;
      return true;
    }
    return false;
  }

  void Evaluate() {
    bool changed = false;
    changed |= Latch(IsCapabilityActive(L"microphone", self_), kMicGraceMs, mic_, mic_seen_);
    changed |= Latch(IsCapabilityActive(L"webcam", self_), kCameraGraceMs, camera_, camera_seen_);

    bool video = false;
    bool focus = false;
    QUERY_USER_NOTIFICATION_STATE state;
    if (SHQueryUserNotificationState(&state) == S_OK) {
      // Exclusive-fullscreen games/players and PowerPoint-style presentation
      // mode. QUNS_BUSY (any maximised app) is deliberately not treated as video:
      // it flags ordinary maximised windows.
      video = state == QUNS_RUNNING_D3D_FULL_SCREEN || state == QUNS_PRESENTATION_MODE;
      focus = state == QUNS_QUIET_TIME;
    }
    if (video != video_) {
      video_ = video;
      changed = true;
    }
    if (focus != focus_) {
      focus_ = focus;
      changed = true;
    }

    if (changed) Push();
  }

  void Push() {
    if (!sink_) return;
    EncodableMap payload;
    payload[EncodableValue("isMicrophoneActive")] = EncodableValue(mic_);
    payload[EncodableValue("isCameraActive")] = EncodableValue(camera_);
    payload[EncodableValue("isInMeeting")] = EncodableValue(mic_ || camera_);
    payload[EncodableValue("isVideoPlaying")] = EncodableValue(video_);
    payload[EncodableValue("isFocusModeActive")] = EncodableValue(focus_);
    payload[EncodableValue("shouldPauseBreaks")] =
        EncodableValue(mic_ || camera_ || video_ || focus_);
    sink_->Success(EncodableValue(payload));
  }

  static SmartDetector* instance_;

  std::unique_ptr<flutter::EventChannel<EncodableValue>> channel_;
  std::unique_ptr<flutter::EventSink<EncodableValue>> sink_;
  UINT_PTR timer_ = 0;
  std::wstring self_;

  bool mic_ = false, camera_ = false, video_ = false, focus_ = false;
  ULONGLONG mic_seen_ = 0, camera_seen_ = 0;
};

SmartDetector* SmartDetector::instance_ = nullptr;

}  // namespace

void RegisterSmartDetectionBridge(flutter::FlutterEngine* engine) {
  // Process-lifetime object; see RegisterNativeEnhancementsBridge.
  new SmartDetector(engine);
}
