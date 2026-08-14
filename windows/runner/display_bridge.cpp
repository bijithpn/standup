#include "display_bridge.h"

#include <string>
#include <vector>
#include <map>
#include <PhysicalMonitorEnumerationAPI.h>

#pragma comment(lib, "dxva2.lib")

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

struct EnumContext {
  std::map<std::wstring, std::wstring> friendlyNames;
};

std::map<std::wstring, std::wstring> GetDisplayFriendlyNamesMap() {
  std::map<std::wstring, std::wstring> namesMap;
  UINT32 numPathArrayElements = 0;
  UINT32 numModeInfoArrayElements = 0;

  LONG result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &numPathArrayElements, &numModeInfoArrayElements);
  if (result != ERROR_SUCCESS) {
    return namesMap;
  }

  std::vector<DISPLAYCONFIG_PATH_INFO> pathArray(numPathArrayElements);
  std::vector<DISPLAYCONFIG_MODE_INFO> modeArray(numModeInfoArrayElements);

  result = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, &numPathArrayElements, pathArray.data(), 
                              &numModeInfoArrayElements, modeArray.data(), nullptr);

  if (result == ERROR_SUCCESS) {
    for (const auto& path : pathArray) {
      DISPLAYCONFIG_SOURCE_DEVICE_NAME sourceName = {};
      sourceName.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
      sourceName.header.size = sizeof(DISPLAYCONFIG_SOURCE_DEVICE_NAME);
      sourceName.header.adapterId = path.sourceInfo.adapterId;
      sourceName.header.id = path.sourceInfo.id;

      if (DisplayConfigGetDeviceInfo(&sourceName.header) == ERROR_SUCCESS) {
        DISPLAYCONFIG_TARGET_DEVICE_NAME targetName = {};
        targetName.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
        targetName.header.size = sizeof(DISPLAYCONFIG_TARGET_DEVICE_NAME);
        targetName.header.adapterId = path.targetInfo.adapterId;
        targetName.header.id = path.targetInfo.id;

        if (DisplayConfigGetDeviceInfo(&targetName.header) == ERROR_SUCCESS) {
          if (targetName.monitorFriendlyDeviceName[0] != L'\0') {
            namesMap[sourceName.viewGdiDeviceName] = targetName.monitorFriendlyDeviceName;
          }
        }
      }
    }
  }
  return namesMap;
}

BOOL CALLBACK MonitorEnumProc(HMONITOR hMonitor, HDC hdcMonitor, LPRECT lprcMonitor, LPARAM dwData) {
  EnumContext* context = reinterpret_cast<EnumContext*>(dwData);
  MONITORINFOEX info;
  info.cbSize = sizeof(MONITORINFOEX);
  GetMonitorInfo(hMonitor, &info);

  DisplayData data;
  char szDevice[32];
  WideCharToMultiByte(CP_UTF8, 0, info.szDevice, -1, szDevice, 32, NULL, NULL);

  // Try to get friendly name from QueryDisplayConfig map first
  std::wstring friendlyName = L"";
  if (context && context->friendlyNames.count(info.szDevice) > 0) {
    friendlyName = context->friendlyNames[info.szDevice];
  }

  // Fallback to Physical Monitor API if QueryDisplayConfig didn't return a name
  if (friendlyName.empty()) {
    DWORD dwCount = 0;
    if (GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, &dwCount)) {
      std::vector<PHYSICAL_MONITOR> monitors(dwCount);
      if (GetPhysicalMonitorsFromHMONITOR(hMonitor, dwCount, monitors.data())) {
        friendlyName = monitors[0].szPhysicalMonitorDescription;
        DestroyPhysicalMonitors(dwCount, monitors.data());
      }
    }
  }

  std::string deviceId = szDevice;
  size_t pos = deviceId.find_last_of("\\");
  if (pos != std::string::npos) {
    deviceId = deviceId.substr(pos + 1);
  }

  if (!friendlyName.empty()) {
    char szFriendly[128];
    WideCharToMultiByte(CP_UTF8, 0, friendlyName.c_str(), -1, szFriendly, 128, NULL, NULL);
    data.id = std::string(szFriendly) + " (" + deviceId + ")";
  } else {
    data.id = deviceId;
  }

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
          EnumContext context;
          context.friendlyNames = GetDisplayFriendlyNamesMap();
          EnumDisplayMonitors(NULL, NULL, MonitorEnumProc, reinterpret_cast<LPARAM>(&context));

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
