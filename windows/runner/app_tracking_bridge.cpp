#include "app_tracking_bridge.h"

#include <windows.h>
#include <psapi.h>
#include <uiautomation.h>
#include <gdiplus.h>
#include <objbase.h>
#include <shellapi.h>
#include <string>
#include <vector>
#include <iostream>
#include <algorithm>

#pragma comment(lib, "gdiplus.lib")

namespace {

std::string Utf16ToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
  std::string strTo(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
  return strTo;
}

std::string GetBrowserUrl(HWND hwnd, const std::string& exe_name) {
  std::string lowercase_exe = exe_name;
  std::transform(lowercase_exe.begin(), lowercase_exe.end(), lowercase_exe.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  if (lowercase_exe != "chrome.exe" && lowercase_exe != "msedge.exe" && lowercase_exe != "firefox.exe") {
    return "";
  }

  // Initialize COM for UI Automation (if not already initialized)
  HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
  bool co_initialized = SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;

  IUIAutomation* pAutomation = nullptr;
  hr = CoCreateInstance(CLSID_CUIAutomation, NULL, CLSCTX_INPROC_SERVER, IID_IUIAutomation, (void**)&pAutomation);
  if (FAILED(hr) || !pAutomation) {
    if (co_initialized && hr != RPC_E_CHANGED_MODE) CoUninitialize();
    return "";
  }

  IUIAutomationElement* pElement = nullptr;
  hr = pAutomation->ElementFromHandle(hwnd, &pElement);
  if (FAILED(hr) || !pElement) {
    pAutomation->Release();
    if (co_initialized && hr != RPC_E_CHANGED_MODE) CoUninitialize();
    return "";
  }

  IUIAutomationCondition* pCondition = nullptr;
  VARIANT varProp;
  varProp.vt = VT_I4;
  varProp.lVal = UIA_EditControlTypeId;
  hr = pAutomation->CreatePropertyCondition(UIA_ControlTypePropertyId, varProp, &pCondition);
  
  std::string url = "";
  if (SUCCEEDED(hr) && pCondition) {
    IUIAutomationElement* pEditElement = nullptr;
    // Walk down the tree to find the first Edit control (address bar)
    hr = pElement->FindFirst(TreeScope_Descendants, pCondition, &pEditElement);
    if (SUCCEEDED(hr) && pEditElement) {
      IUIAutomationValuePattern* pValuePattern = nullptr;
      hr = pEditElement->GetCurrentPattern(UIA_ValuePatternId, (IUnknown**)&pValuePattern);
      if (SUCCEEDED(hr) && pValuePattern) {
        BSTR bstrVal;
        if (SUCCEEDED(pValuePattern->get_CurrentValue(&bstrVal)) && bstrVal) {
          std::wstring wstr(bstrVal, SysStringLen(bstrVal));
          url = Utf16ToUtf8(wstr);
          SysFreeString(bstrVal);
        }
        pValuePattern->Release();
      }
      pEditElement->Release();
    }
    pCondition->Release();
  }

  pElement->Release();
  pAutomation->Release();
  if (co_initialized && hr != RPC_E_CHANGED_MODE) CoUninitialize();
  return url;
}

ULONG_PTR g_gdiplus_token = 0;
bool g_gdiplus_started = false;

void EnsureGdiplusStarted() {
  if (g_gdiplus_started) return;
  Gdiplus::GdiplusStartupInput input;
  Gdiplus::GdiplusStartup(&g_gdiplus_token, &input, NULL);
  g_gdiplus_started = true;
}

int GetPngEncoderClsid(CLSID* clsid) {
  UINT num = 0;
  UINT size = 0;
  Gdiplus::GetImageEncodersSize(&num, &size);
  if (size == 0) return -1;

  std::vector<BYTE> buffer(size);
  auto* codec_info = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.data());
  Gdiplus::GetImageEncoders(num, size, codec_info);

  for (UINT i = 0; i < num; i++) {
    if (wcscmp(codec_info[i].MimeType, L"image/png") == 0) {
      *clsid = codec_info[i].Clsid;
      return 0;
    }
  }
  return -1;
}

// Extracts the icon embedded in an executable and encodes it as PNG bytes.
// Returns an empty vector on any failure (missing file, no icon, encode error).
std::vector<uint8_t> ExtractIconAsPng(const std::wstring& exe_path) {
  std::vector<uint8_t> png_bytes;
  if (exe_path.empty()) return png_bytes;

  EnsureGdiplusStarted();

  HICON hicon = nullptr;
  UINT extracted = ExtractIconExW(exe_path.c_str(), 0, nullptr, &hicon, 1);
  if (extracted == 0 || hicon == nullptr) return png_bytes;

  Gdiplus::Bitmap bitmap(hicon);
  CLSID png_clsid;
  if (GetPngEncoderClsid(&png_clsid) != 0) {
    DestroyIcon(hicon);
    return png_bytes;
  }

  IStream* stream = nullptr;
  if (FAILED(CreateStreamOnHGlobal(NULL, TRUE, &stream)) || stream == nullptr) {
    DestroyIcon(hicon);
    return png_bytes;
  }

  if (bitmap.Save(stream, &png_clsid, nullptr) == Gdiplus::Ok) {
    STATSTG stat;
    stream->Stat(&stat, STATFLAG_NONAME);
    ULONG size = static_cast<ULONG>(stat.cbSize.QuadPart);

    LARGE_INTEGER zero = {};
    stream->Seek(zero, STREAM_SEEK_SET, nullptr);

    png_bytes.resize(size);
    ULONG read = 0;
    stream->Read(png_bytes.data(), size, &read);
    png_bytes.resize(read);
  }

  stream->Release();
  DestroyIcon(hicon);
  return png_bytes;
}

} // namespace

/// Registers the active app tracking method channel.
/// Querying the foreground window helps track user focus patterns and suppress notifications or
/// breaks during full-screen presentation apps.
void RegisterAppTrackingBridge(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "com.breakmate/app_tracking",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getActiveApp") {
          // Identify the current top-level focused window.
          HWND foreground = GetForegroundWindow();
          if (!foreground) {
            result->Success();
            return;
          }

          DWORD process_id;
          GetWindowThreadProcessId(foreground, &process_id);

          // PROCESS_QUERY_LIMITED_INFORMATION is used for compatibility across sandboxed or
          // higher integrity level processes without triggering UAC check constraints.
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

          std::string url = GetBrowserUrl(foreground, exe_name);

          flutter::EncodableMap map;
          map[flutter::EncodableValue("name")] = flutter::EncodableValue(title);
          map[flutter::EncodableValue("bundleId")] = flutter::EncodableValue(exe_path);
          map[flutter::EncodableValue("executableName")] = flutter::EncodableValue(exe_name);
          if (!url.empty()) {
            map[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
          }

          result->Success(flutter::EncodableValue(map));
        } else if (call.method_name() == "getAppIcon") {
          std::wstring exe_path;
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("bundleId"));
            if (it != args->end()) {
              const auto* path_utf8 = std::get_if<std::string>(&it->second);
              if (path_utf8 && !path_utf8->empty()) {
                int wlen = MultiByteToWideChar(CP_UTF8, 0, path_utf8->c_str(), -1, NULL, 0);
                std::vector<wchar_t> wbuf(wlen);
                MultiByteToWideChar(CP_UTF8, 0, path_utf8->c_str(), -1, wbuf.data(), wlen);
                exe_path = wbuf.data();
              }
            }
          }

          std::vector<uint8_t> png = ExtractIconAsPng(exe_path);
          if (png.empty()) {
            result->Success();
          } else {
            result->Success(flutter::EncodableValue(png));
          }
        } else {
          result->NotImplemented();
        }
      });

  // Release the channel to prevent it from being destroyed
  channel.release();
}
