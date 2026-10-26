#include "constraint_window.h"

#include <windows.h>
#include <flutter_windows.h>

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr const wchar_t kClass[] = L"BreakMateConstraintZone";
constexpr COLORREF kKey = RGB(255, 0, 255);  // becomes transparent + click-through
constexpr int kMinDip = 200;
constexpr int kMaxDip = 800;

HWND g_hwnd = nullptr;
std::unique_ptr<flutter::EventSink<EncodableValue>> g_sink;

double ScaleAt(int px_x, int px_y) {
  POINT pt = {px_x, px_y};
  HMONITOR mon = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(mon);
  return dpi ? static_cast<double>(dpi) / 96.0 : 1.0;
}

void EmitBounds() {
  if (!g_hwnd || !g_sink) return;
  RECT r;
  if (!GetWindowRect(g_hwnd, &r)) return;
  double s = ScaleAt(r.left, r.top);
  EncodableMap payload;
  payload[EncodableValue("x")] = EncodableValue(r.left / s);
  payload[EncodableValue("y")] = EncodableValue(r.top / s);
  payload[EncodableValue("width")] = EncodableValue((r.right - r.left) / s);
  payload[EncodableValue("height")] = EncodableValue((r.bottom - r.top) / s);
  g_sink->Success(EncodableValue(payload));
}

LRESULT CALLBACK ZoneProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
  switch (msg) {
    case WM_ERASEBKGND: {
      HDC dc = reinterpret_cast<HDC>(wp);
      RECT rc;
      GetClientRect(hwnd, &rc);
      HBRUSH key = CreateSolidBrush(kKey);
      FillRect(dc, &rc, key);
      DeleteObject(key);

      // Dashed blue border, as on macOS.
      LOGBRUSH lb = {BS_SOLID, RGB(10, 132, 255), 0};
      DWORD dashes[2] = {8, 4};
      HPEN pen = ExtCreatePen(PS_GEOMETRIC | PS_USERSTYLE, 2, &lb, 2, dashes);
      HGDIOBJ old_pen = SelectObject(dc, pen);
      HGDIOBJ old_brush = SelectObject(dc, GetStockObject(NULL_BRUSH));
      Rectangle(dc, rc.left + 2, rc.top + 2, rc.right - 2, rc.bottom - 2);
      SelectObject(dc, old_brush);
      SelectObject(dc, old_pen);
      DeleteObject(pen);
      return 1;
    }
    case WM_GETMINMAXINFO: {
      auto* mmi = reinterpret_cast<MINMAXINFO*>(lp);
      UINT dpi = GetDpiForWindow(hwnd);
      double s = dpi ? dpi / 96.0 : 1.0;
      mmi->ptMinTrackSize = {static_cast<LONG>(kMinDip * s), static_cast<LONG>(kMinDip * s)};
      mmi->ptMaxTrackSize = {static_cast<LONG>(kMaxDip * s), static_cast<LONG>(kMaxDip * s)};
      return 0;
    }
    case WM_MOVE:
    case WM_SIZE:
      EmitBounds();
      return 0;
    case WM_CLOSE:
      HideConstraintWindow();
      return 0;
    case WM_DESTROY:
      if (hwnd == g_hwnd) g_hwnd = nullptr;
      return 0;
  }
  return DefWindowProc(hwnd, msg, wp, lp);
}

}  // namespace

void ShowConstraintWindow(double x, double y, double width, double height) {
  double s = ScaleAt(static_cast<int>(x), static_cast<int>(y));
  int px = static_cast<int>(x * s);
  int py = static_cast<int>(y * s);
  int pw = static_cast<int>(width * s);
  int ph = static_cast<int>(height * s);

  if (g_hwnd) {
    SetWindowPos(g_hwnd, HWND_TOPMOST, px, py, pw, ph, SWP_NOACTIVATE | SWP_SHOWWINDOW);
    return;
  }

  WNDCLASSW wc = {};
  if (!GetClassInfoW(GetModuleHandle(nullptr), kClass, &wc)) {
    wc.lpfnWndProc = ZoneProc;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.lpszClassName = kClass;
    RegisterClassW(&wc);
  }

  g_hwnd = CreateWindowExW(WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TOOLWINDOW, kClass,
                           L"Constraint Zone", WS_OVERLAPPED | WS_CAPTION | WS_THICKFRAME | WS_SYSMENU,
                           px, py, pw, ph, nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
  if (!g_hwnd) return;
  SetLayeredWindowAttributes(g_hwnd, kKey, 255, LWA_COLORKEY);
  ShowWindow(g_hwnd, SW_SHOWNOACTIVATE);
}

void HideConstraintWindow() {
  if (!g_hwnd) return;
  HWND h = g_hwnd;
  g_hwnd = nullptr;
  DestroyWindow(h);
}

void RegisterConstraintWindowBridge(flutter::FlutterEngine* engine) {
  // Process-lifetime channel; see RegisterNativeEnhancementsBridge.
  auto* channel = new flutter::EventChannel<EncodableValue>(
      engine->messenger(), "com.breakmate.desktop/constraintWindowBounds",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
      [](const EncodableValue*, std::unique_ptr<flutter::EventSink<EncodableValue>>&& sink)
          -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
        g_sink = std::move(sink);
        return nullptr;
      },
      [](const EncodableValue*) -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
        g_sink = nullptr;
        return nullptr;
      }));
}
