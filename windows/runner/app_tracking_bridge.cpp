#include "app_tracking_bridge.h"

#include <windows.h>
#include <psapi.h>
#include <string>
#include <iostream>
#include <algorithm>

namespace {

std::string Utf16ToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
  std::string strTo(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
  return strTo;
}

} // namespace

void RegisterAppTrackingBridge(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "com.breakmate/app_tracking",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getActiveApp") {
          HWND foreground = GetForegroundWindow();
          if (!foreground) {
            result->Success();
            return;
          }

          DWORD process_id;
          GetWindowThreadProcessId(foreground, &process_id);

          HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
          if (!process) {
            result->Success();
            return;
          }

          std::wstring exe_path_w;
          DWORD size = MAX_PATH;
          wchar_t buffer[MAX_PATH];
          if (QueryFullProcessImageNameW(process, 0, buffer, &size)) {
            exe_path_w = buffer;
          }
          CloseHandle(process);

          std::wstring title_w;
          int length = GetWindowTextLengthW(foreground);
          if (length > 0) {
            std::vector<wchar_t> title_buffer(length + 1);
            if (GetWindowTextW(foreground, title_buffer.data(), length + 1)) {
              title_w = std::wstring(title_buffer.data(), length);
            }
          }

          std::string title = Utf16ToUtf8(title_w);
          std::string exe_path = Utf16ToUtf8(exe_path_w);
          std::string exe_name;

          size_t slash_pos = exe_path.find_last_of("\\/");
          if (slash_pos != std::string::npos) {
            exe_name = exe_path.substr(slash_pos + 1);
          } else {
            exe_name = exe_path;
          }

          flutter::EncodableMap map;
          map[flutter::EncodableValue("name")] = flutter::EncodableValue(title);
          map[flutter::EncodableValue("bundleId")] = flutter::EncodableValue(exe_path);
          map[flutter::EncodableValue("executableName")] = flutter::EncodableValue(exe_name);

          result->Success(flutter::EncodableValue(map));
        } else {
          result->NotImplemented();
        }
      });

  // Release the channel to prevent it from being destroyed
  channel.release();
}
