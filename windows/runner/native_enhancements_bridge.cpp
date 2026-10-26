#include "native_enhancements_bridge.h"

#include <windows.h>
#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <memory>
#include <string>
#include <vector>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

template <typename T>
T ArgOr(const EncodableValue* args, const char* key, T fallback) {
  const auto* map = args ? std::get_if<EncodableMap>(args) : nullptr;
  if (!map) return fallback;
  auto it = map->find(EncodableValue(key));
  if (it == map->end()) return fallback;
  if (const auto* v = std::get_if<T>(&it->second)) return *v;
  return fallback;
}

double NumArgOr(const EncodableValue* args, const char* key, double fallback) {
  const auto* map = args ? std::get_if<EncodableMap>(args) : nullptr;
  if (!map) return fallback;
  auto it = map->find(EncodableValue(key));
  if (it == map->end()) return fallback;
  if (const auto* d = std::get_if<double>(&it->second)) return *d;
  if (const auto* i = std::get_if<int32_t>(&it->second)) return *i;
  if (const auto* l = std::get_if<int64_t>(&it->second)) return static_cast<double>(*l);
  return fallback;
}

std::wstring Widen(const std::string& s) {
  if (s.empty()) return std::wstring();
  int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
  std::wstring w(n, 0);
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), &w[0], n);
  return w;
}

COLORREF ParseHex(const std::string& hex, COLORREF fallback) {
  std::string h = hex;
  if (!h.empty() && h[0] == '#') h.erase(0, 1);
  if (h.size() != 6) return fallback;
  try {
    unsigned long v = std::stoul(h, nullptr, 16);
    return RGB((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
  } catch (...) {
    return fallback;
  }
}

int Scale(HWND hwnd, int v) {
  UINT dpi = hwnd ? GetDpiForWindow(hwnd) : GetDpiForSystem();
  if (dpi == 0) dpi = 96;
  return MulDiv(v, (int)dpi, 96);
}

void EnsureClass(const wchar_t* name, WNDPROC proc) {
  WNDCLASSW wc = {};
  if (GetClassInfoW(GetModuleHandle(nullptr), name, &wc)) return;
  wc.lpfnWndProc = proc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.lpszClassName = name;
  RegisterClassW(&wc);
}

constexpr DWORD kOverlayExStyle = WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW |
                                  WS_EX_TRANSPARENT | WS_EX_NOACTIVATE;

// ---------------------------------------------------------------------------
// Display sleep prevention (PowerSetRequest is not tied to a calling thread,
// unlike SetThreadExecutionState).
// ---------------------------------------------------------------------------
class PowerAssertion {
 public:
  void Prevent(const std::string& reason) {
    if (request_ != INVALID_HANDLE_VALUE) return;
    reason_ = Widen(reason);
    REASON_CONTEXT ctx = {};
    ctx.Version = POWER_REQUEST_CONTEXT_VERSION;
    ctx.Flags = POWER_REQUEST_CONTEXT_SIMPLE_STRING;
    ctx.Reason.SimpleReasonString = const_cast<LPWSTR>(reason_.c_str());
    HANDLE h = PowerCreateRequest(&ctx);
    if (h == INVALID_HANDLE_VALUE || h == nullptr) return;
    if (!PowerSetRequest(h, PowerRequestDisplayRequired)) {
      CloseHandle(h);
      return;
    }
    request_ = h;
  }

  void Release() {
    if (request_ == INVALID_HANDLE_VALUE) return;
    PowerClearRequest(request_, PowerRequestDisplayRequired);
    CloseHandle(request_);
    request_ = INVALID_HANDLE_VALUE;
  }

 private:
  HANDLE request_ = INVALID_HANDLE_VALUE;
  std::wstring reason_;
};

// ---------------------------------------------------------------------------
// Cursor countdown pill: small click-through window that trails the pointer.
// ---------------------------------------------------------------------------
class CursorCountdown {
 public:
  void Start(int seconds) {
    remaining_ = seconds;
    EnsureClass(kClass, &CursorCountdown::WndProc);
    if (!hwnd_) {
      hwnd_ = CreateWindowExW(kOverlayExStyle, kClass, L"", WS_POPUP, 0, 0, 64, 26,
                              nullptr, nullptr, GetModuleHandle(nullptr), this);
      if (!hwnd_) return;
      SetWindowLongPtr(hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
    }
    Layout();
    SetLayeredWindowAttributes(hwnd_, 0, 235, LWA_ALPHA);
    ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
    SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    InvalidateRect(hwnd_, nullptr, TRUE);
    SetTimer(hwnd_, kTrackTimer, 16, nullptr);
    SetTimer(hwnd_, kSecondTimer, 1000, nullptr);
  }

  void Dismiss() {
    if (!hwnd_) return;
    KillTimer(hwnd_, kTrackTimer);
    KillTimer(hwnd_, kSecondTimer);
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
    shaped_w_ = shaped_h_ = 0;
  }

 private:
  static constexpr const wchar_t* kClass = L"BreakMateCursorCountdown";
  static constexpr UINT_PTR kTrackTimer = 1;
  static constexpr UINT_PTR kSecondTimer = 2;

  void Layout() {
    POINT pt;
    GetCursorPos(&pt);
    HMONITOR mon = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = {sizeof(mi)};
    GetMonitorInfo(mon, &mi);
    const RECT& work = mi.rcWork;

    int w = Scale(hwnd_, 64);
    int h = Scale(hwnd_, 26);
    int gap = Scale(hwnd_, 16);
    int margin = Scale(hwnd_, 4);

    // Default: bottom-right of the pointer; flip when it would leave the screen.
    int x = pt.x + gap;
    int y = pt.y + gap;
    if (x + w > work.right) x = pt.x - w - Scale(hwnd_, 10);
    if (x < work.left + margin) x = work.left + margin;
    if (y + h > work.bottom - margin) y = pt.y - h - gap;
    if (y < work.top + margin) y = work.top + margin;

    SetWindowPos(hwnd_, HWND_TOPMOST, x, y, w, h, SWP_NOACTIVATE);
    // The shape only changes with the size (i.e. when moving between monitors
    // of different DPI); re-applying it every frame would force a repaint.
    if (w != shaped_w_ || h != shaped_h_) {
      SetWindowRgn(hwnd_, CreateRoundRectRgn(0, 0, w + 1, h + 1, h, h), TRUE);
      shaped_w_ = w;
      shaped_h_ = h;
    }
  }

  void Paint() {
    PAINTSTRUCT ps;
    HDC dc = BeginPaint(hwnd_, &ps);
    RECT rc;
    GetClientRect(hwnd_, &rc);

    HBRUSH bg = CreateSolidBrush(RGB(28, 28, 30));
    FillRect(dc, &rc, bg);
    DeleteObject(bg);

    int dot = Scale(hwnd_, 6);
    int cy = (rc.bottom - rc.top) / 2;
    int dot_x = Scale(hwnd_, 12);
    HBRUSH orange = CreateSolidBrush(RGB(255, 149, 0));
    HGDIOBJ old_brush = SelectObject(dc, orange);
    HGDIOBJ old_pen = SelectObject(dc, GetStockObject(NULL_PEN));
    Ellipse(dc, dot_x, cy - dot / 2, dot_x + dot, cy + dot / 2);
    SelectObject(dc, old_pen);
    SelectObject(dc, old_brush);
    DeleteObject(orange);

    HFONT font = CreateFontW(-Scale(hwnd_, 13), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                             DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                             CLEARTYPE_QUALITY, FIXED_PITCH | FF_MODERN, L"Segoe UI");
    HGDIOBJ old_font = SelectObject(dc, font);
    SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, RGB(255, 255, 255));
    std::wstring text = std::to_wstring(remaining_) + L"s";
    RECT text_rc = rc;
    text_rc.left = dot_x + dot + Scale(hwnd_, 5);
    DrawTextW(dc, text.c_str(), -1, &text_rc, DT_SINGLELINE | DT_VCENTER | DT_LEFT);
    SelectObject(dc, old_font);
    DeleteObject(font);
    EndPaint(hwnd_, &ps);
  }

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* self = reinterpret_cast<CursorCountdown*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (self) {
      switch (msg) {
        case WM_PAINT:
          self->Paint();
          return 0;
        case WM_ERASEBKGND:
          return 1;
        case WM_TIMER:
          if (wp == kTrackTimer) {
            self->Layout();
          } else if (wp == kSecondTimer) {
            if (--self->remaining_ > 0) {
              InvalidateRect(hwnd, nullptr, FALSE);
            } else {
              self->Dismiss();
            }
          }
          return 0;
        case WM_NCHITTEST:
          return HTTRANSPARENT;
      }
    }
    return DefWindowProc(hwnd, msg, wp, lp);
  }

  HWND hwnd_ = nullptr;
  int remaining_ = 15;
  int shaped_w_ = 0;
  int shaped_h_ = 0;
};

// ---------------------------------------------------------------------------
// Flash reminder: a tinted full-monitor layer with a centred text pill.
// ---------------------------------------------------------------------------
class FlashReminder {
 public:
  void Trigger(const std::string& text, int duration_ms, double opacity,
               const std::string& color_hex) {
    Dismiss();
    text_ = Widen(text);
    tint_ = ParseHex(color_hex, RGB(0, 0, 0));
    BYTE alpha = (BYTE)(std::clamp(opacity, 0.0, 1.0) * 255.0);

    EnsureClass(kTintClass, &FlashReminder::TintProc);
    EnsureClass(kPillClass, &FlashReminder::PillProc);

    EnumDisplayMonitors(nullptr, nullptr, &FlashReminder::EnumMonitor,
                        reinterpret_cast<LPARAM>(this));
    for (HWND h : tints_) SetLayeredWindowAttributes(h, 0, alpha, LWA_ALPHA);
    for (HWND h : pills_) SetLayeredWindowAttributes(h, 0, 240, LWA_ALPHA);

    // The pill is created per-monitor in EnumMonitor, so only the timer owner
    // needs to exist once.
    EnsureTimerWindow();
    SetTimer(timer_hwnd_, 1, (UINT)std::max(duration_ms, 50), nullptr);
  }

  void Dismiss() {
    if (timer_hwnd_) KillTimer(timer_hwnd_, 1);
    for (HWND h : tints_) DestroyWindow(h);
    for (HWND h : pills_) DestroyWindow(h);
    tints_.clear();
    pills_.clear();
  }

 private:
  static constexpr const wchar_t* kTintClass = L"BreakMateFlashTint";
  static constexpr const wchar_t* kPillClass = L"BreakMateFlashPill";
  static constexpr const wchar_t* kTimerClass = L"BreakMateFlashTimer";

  static BOOL CALLBACK EnumMonitor(HMONITOR, HDC, LPRECT rect, LPARAM data) {
    auto* self = reinterpret_cast<FlashReminder*>(data);
    HINSTANCE inst = GetModuleHandle(nullptr);

    HWND tint = CreateWindowExW(kOverlayExStyle, kTintClass, L"", WS_POPUP, rect->left,
                                rect->top, rect->right - rect->left, rect->bottom - rect->top,
                                nullptr, nullptr, inst, self);
    if (!tint) return TRUE;
    SetWindowLongPtr(tint, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    SetLayeredWindowAttributes(tint, 0, 90, LWA_ALPHA);
    ShowWindow(tint, SW_SHOWNOACTIVATE);
    self->tints_.push_back(tint);

    int mon_w = rect->right - rect->left;
    int mon_h = rect->bottom - rect->top;
    int pill_w = std::min(Scale(tint, 540), mon_w - Scale(tint, 80));
    int pill_h = Scale(tint, 84);
    HWND pill = CreateWindowExW(kOverlayExStyle, kPillClass, L"", WS_POPUP,
                                rect->left + (mon_w - pill_w) / 2,
                                rect->top + (mon_h - pill_h) / 2, pill_w, pill_h, nullptr,
                                nullptr, inst, self);
    if (!pill) return TRUE;
    SetWindowLongPtr(pill, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    SetLayeredWindowAttributes(pill, 0, 240, LWA_ALPHA);
    HRGN rgn = CreateRoundRectRgn(0, 0, pill_w + 1, pill_h + 1, Scale(tint, 24) * 2,
                                  Scale(tint, 24) * 2);
    SetWindowRgn(pill, rgn, TRUE);
    ShowWindow(pill, SW_SHOWNOACTIVATE);
    self->pills_.push_back(pill);
    return TRUE;
  }

  void EnsureTimerWindow() {
    if (timer_hwnd_) return;
    WNDCLASSW wc = {};
    if (!GetClassInfoW(GetModuleHandle(nullptr), kTimerClass, &wc)) {
      wc.lpfnWndProc = &FlashReminder::TimerProc;
      wc.hInstance = GetModuleHandle(nullptr);
      wc.lpszClassName = kTimerClass;
      RegisterClassW(&wc);
    }
    timer_hwnd_ = CreateWindowExW(0, kTimerClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr,
                                  GetModuleHandle(nullptr), nullptr);
    SetWindowLongPtr(timer_hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
  }

  static LRESULT CALLBACK TimerProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_TIMER) {
      auto* self = reinterpret_cast<FlashReminder*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
      if (self) self->Dismiss();
      return 0;
    }
    return DefWindowProc(hwnd, msg, wp, lp);
  }

  static LRESULT CALLBACK TintProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* self = reinterpret_cast<FlashReminder*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (self && msg == WM_ERASEBKGND) {
      HDC dc = reinterpret_cast<HDC>(wp);
      RECT rc;
      GetClientRect(hwnd, &rc);
      HBRUSH brush = CreateSolidBrush(self->tint_);
      FillRect(dc, &rc, brush);
      DeleteObject(brush);
      return 1;
    }
    if (msg == WM_NCHITTEST) return HTTRANSPARENT;
    return DefWindowProc(hwnd, msg, wp, lp);
  }

  static LRESULT CALLBACK PillProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* self = reinterpret_cast<FlashReminder*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (self && msg == WM_PAINT) {
      PAINTSTRUCT ps;
      HDC dc = BeginPaint(hwnd, &ps);
      RECT rc;
      GetClientRect(hwnd, &rc);
      HBRUSH bg = CreateSolidBrush(RGB(28, 28, 30));
      FillRect(dc, &rc, bg);
      DeleteObject(bg);
      HFONT font = CreateFontW(-Scale(hwnd, 26), 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                               DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                               CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
      HGDIOBJ old = SelectObject(dc, font);
      SetBkMode(dc, TRANSPARENT);
      SetTextColor(dc, RGB(255, 255, 255));
      RECT text_rc = rc;
      InflateRect(&text_rc, -Scale(hwnd, 24), 0);
      DrawTextW(dc, self->text_.c_str(), -1, &text_rc,
                DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_END_ELLIPSIS);
      SelectObject(dc, old);
      DeleteObject(font);
      EndPaint(hwnd, &ps);
      return 0;
    }
    if (msg == WM_ERASEBKGND) return 1;
    if (msg == WM_NCHITTEST) return HTTRANSPARENT;
    return DefWindowProc(hwnd, msg, wp, lp);
  }

  std::vector<HWND> tints_;
  std::vector<HWND> pills_;
  HWND timer_hwnd_ = nullptr;
  std::wstring text_;
  COLORREF tint_ = RGB(0, 0, 0);
};

// The bridge objects live for the whole process, on purpose: their windows are
// destroyed with it, and tearing them down during static destruction (after the
// Flutter engine is gone) is what we avoid.
PowerAssertion* g_power = nullptr;
CursorCountdown* g_cursor = nullptr;
FlashReminder* g_flash = nullptr;

}  // namespace

void RegisterNativeEnhancementsBridge(flutter::FlutterEngine* engine) {
  g_power = new PowerAssertion();
  g_cursor = new CursorCountdown();
  g_flash = new FlashReminder();

  // Leaked intentionally for the same reason as the objects above.
  auto* channel = new flutter::MethodChannel<EncodableValue>(
      engine->messenger(), "com.breakmate/native_enhancements",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        const std::string& method = call.method_name();
        const EncodableValue* args = call.arguments();

        if (method == "showCursorCountdown") {
          g_cursor->Start((int)NumArgOr(args, "seconds", 15));
          result->Success();
        } else if (method == "hideCursorCountdown") {
          g_cursor->Dismiss();
          result->Success();
        } else if (method == "triggerFlashReminder") {
          std::string text = ArgOr<std::string>(args, "text", "");
          if (text.empty()) {
            result->Error("INVALID_ARGS", "text required");
            return;
          }
          g_flash->Trigger(text, (int)NumArgOr(args, "durationMs", 250),
                           NumArgOr(args, "opacity", 0.35),
                           ArgOr<std::string>(args, "colorHex", "#000000"));
          result->Success();
        } else if (method == "preventDisplaySleep") {
          g_power->Prevent(ArgOr<std::string>(args, "reason", "BreakMate Break Active"));
          result->Success();
        } else if (method == "releaseDisplaySleep") {
          g_power->Release();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}
