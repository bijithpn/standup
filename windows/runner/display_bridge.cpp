#include "display_bridge.h"

#include <string>
#include <vector>

struct DisplayData {
  std::string id;
  bool isPrimary;
  double width;
  double height;
  double pixelRatio;
  RECT bounds;
  RECT workArea;
};

static std::vector<DisplayData> g_displays;

BOOL CALLBACK MonitorEnumProc(HMONITOR hMonitor, HDC hdcMonitor, LPRECT lprcMonitor, LPARAM dwData) {
  MONITORINFOEX info;
  info.cbSize = sizeof(MONITORINFOEX);
  GetMonitorInfo(hMonitor, &info);

  DisplayData data;
  char szDevice[32];
  WideCharToMultiByte(CP_UTF8, 0, info.szDevice, -1, szDevice, 32, NULL, NULL);
  data.id = std::string(szDevice);
  data.isPrimary = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
  data.width = static_cast<double>(info.rcMonitor.right - info.rcMonitor.left);
  data.height = static_cast<double>(info.rcMonitor.bottom - info.rcMonitor.top);
  data.bounds = info.rcMonitor;
  data.workArea = info.rcWork;
  
  // Use effective DPI because Flutter sizes the desktop UI in logical pixels.
  UINT dpiX = 96, dpiY = 96;
  HMODULE hUser32 = LoadLibrary(L"user32.dll");
  if (hUser32) {
      typedef UINT(STDAPICALLTYPE * GetDpiForMonitorFn)(HMONITOR, int, UINT*, UINT*);
      GetDpiForMonitorFn getDpiForMonitor = (GetDpiForMonitorFn)GetProcAddress(hUser32, "GetDpiForMonitor");
      if (getDpiForMonitor) {
          getDpiForMonitor(hMonitor, 0 /* MDT_EFFECTIVE_DPI */, &dpiX, &dpiY);
      }
      FreeLibrary(hUser32);
  }
  data.pixelRatio = static_cast<double>(dpiX) / 96.0;

  g_displays.push_back(data);
  return TRUE;
}

void RegisterDisplayBridge(flutter::FlutterEngine* engine, DisplayStreamHandler** handler_out) {
  // This channel is queried by Dart when display geometry is needed.
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "com.breakmate/display_bridge",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() == "getDisplays") {
          g_displays.clear();
          EnumDisplayMonitors(NULL, NULL, MonitorEnumProc, 0);

          flutter::EncodableList list;
          for (const auto& d : g_displays) {
            double scale = d.pixelRatio;
            double logicalWidth = d.width / scale;
            double logicalHeight = d.height / scale;
            double logicalBoundsX = static_cast<double>(d.bounds.left) / scale;
            double logicalBoundsY = static_cast<double>(d.bounds.top) / scale;
            double logicalWorkAreaX = static_cast<double>(d.workArea.left) / scale;
            double logicalWorkAreaY = static_cast<double>(d.workArea.top) / scale;
            double logicalWorkAreaWidth = static_cast<double>(d.workArea.right - d.workArea.left) / scale;
            double logicalWorkAreaHeight = static_cast<double>(d.workArea.bottom - d.workArea.top) / scale;

            flutter::EncodableMap map;
            map[flutter::EncodableValue("id")] = flutter::EncodableValue(d.id);
            map[flutter::EncodableValue("isPrimary")] = flutter::EncodableValue(d.isPrimary);
            
            // Expected by both DisplayInfo and NativeDisplayInfo
            map[flutter::EncodableValue("width")] = flutter::EncodableValue(logicalWidth);
            map[flutter::EncodableValue("height")] = flutter::EncodableValue(logicalHeight);
            map[flutter::EncodableValue("pixelRatio")] = flutter::EncodableValue(scale);
            map[flutter::EncodableValue("dpiScale")] = flutter::EncodableValue(scale);
            
            map[flutter::EncodableValue("boundsX")] = flutter::EncodableValue(logicalBoundsX);
            map[flutter::EncodableValue("boundsY")] = flutter::EncodableValue(logicalBoundsY);
            map[flutter::EncodableValue("x")] = flutter::EncodableValue(logicalBoundsX);
            map[flutter::EncodableValue("y")] = flutter::EncodableValue(logicalBoundsY);
            
            map[flutter::EncodableValue("boundsWidth")] = flutter::EncodableValue(logicalWidth);
            map[flutter::EncodableValue("boundsHeight")] = flutter::EncodableValue(logicalHeight);
            
            map[flutter::EncodableValue("workAreaX")] = flutter::EncodableValue(logicalWorkAreaX);
            map[flutter::EncodableValue("workAreaY")] = flutter::EncodableValue(logicalWorkAreaY);
            map[flutter::EncodableValue("workAreaWidth")] = flutter::EncodableValue(logicalWorkAreaWidth);
            map[flutter::EncodableValue("workAreaHeight")] = flutter::EncodableValue(logicalWorkAreaHeight);
            map[flutter::EncodableValue("refreshRate")] = flutter::EncodableValue(60.0);
            
            list.push_back(flutter::EncodableValue(map));
          }
          result->Success(flutter::EncodableValue(list));
        } else {
          result->NotImplemented();
        }
      });

  // The event channel only signals that display state changed; Dart performs a
  // fresh enumeration so all geometry comes from one code path.
  auto handler = std::make_unique<DisplayStreamHandler>();
  *handler_out = handler.get();
  auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      engine->messenger(), "com.breakmate/display_events",
      &flutter::StandardMethodCodec::GetInstance());
  event_channel->SetStreamHandler(std::move(handler));

  // TODO: Store these channels in a runner-owned registry so their
  // lifetime is explicit instead of relying on release() from setup code.
  channel.release();
  event_channel.release();
}
