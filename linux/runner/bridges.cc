#include "bridges.h"

#include <algorithm>
#include <memory>
#include <string>
#include <vector>

#include "enhancements.h"
#include "secondary_windows.h"
#include "system_info.h"
#include "window_channel.h"
#include "window_util.h"

namespace bm {
namespace {

GtkWindow* g_main_window = nullptr;

// Process-lifetime streams the display-change handler pushes into.
EventStream* g_display_events = nullptr;
EventStream* g_display_change = nullptr;

// ---------------------------------------------------------------------------
// Encoding
// ---------------------------------------------------------------------------

FlValue* EncodeDisplayForBridge(const sys::DisplayRect& d) {
  FlValue* map = fl_value_new_map();
  SetStr(map, "id", d.id);
  SetBool(map, "isPrimary", d.primary);
  SetNum(map, "x", d.x);
  SetNum(map, "y", d.y);
  SetNum(map, "width", d.width);
  SetNum(map, "height", d.height);
  SetNum(map, "dpiScale", d.scale);
  return map;
}

// Matches the keys the Windows runner sends for com.breakmate/display_bridge.
FlValue* EncodeDisplayDetailed(const sys::DisplayRect& d) {
  FlValue* map = EncodeDisplayForBridge(d);
  SetNum(map, "pixelRatio", d.scale);
  SetNum(map, "boundsX", d.x);
  SetNum(map, "boundsY", d.y);
  SetNum(map, "boundsWidth", d.width);
  SetNum(map, "boundsHeight", d.height);
  SetNum(map, "workAreaX", d.work_x);
  SetNum(map, "workAreaY", d.work_y);
  SetNum(map, "workAreaWidth", d.work_width);
  SetNum(map, "workAreaHeight", d.work_height);
  SetNum(map, "refreshRate", d.refresh_hz);
  return map;
}

FlValue* DisplayList(bool detailed) {
  FlValue* list = fl_value_new_list();
  for (const sys::DisplayRect& d : sys::GetDisplays()) {
    fl_value_append_take(list, detailed ? EncodeDisplayDetailed(d) : EncodeDisplayForBridge(d));
  }
  return list;
}

// ---------------------------------------------------------------------------
// Constrained-mode zone: a resizable frame the companion stays inside.
// ---------------------------------------------------------------------------

class ConstraintZone {
 public:
  static ConstraintZone& Get() {
    static ConstraintZone* instance = new ConstraintZone();
    return *instance;
  }

  void SetBoundsStream(EventStream* stream) { bounds_ = stream; }

  void Show(double x, double y, double w, double h) {
    if (window_ == nullptr) {
      window_ = gtk_window_new(GTK_WINDOW_TOPLEVEL);
      GtkWindow* win = GTK_WINDOW(window_);
      gtk_window_set_title(win, "Constraint Zone");
      gtk_window_set_keep_above(win, TRUE);
      gtk_window_stick(win);
      gtk_window_set_skip_taskbar_hint(win, TRUE);
      EnableTransparency(window_);

      GdkGeometry limits = {};
      limits.min_width = limits.min_height = 200;
      limits.max_width = limits.max_height = 800;
      gtk_window_set_geometry_hints(win, nullptr, &limits,
                                    static_cast<GdkWindowHints>(GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE));

      g_signal_connect(window_, "draw", G_CALLBACK(&ConstraintZone::OnDraw), nullptr);
      g_signal_connect(window_, "configure-event", G_CALLBACK(&ConstraintZone::OnConfigure), this);
      g_signal_connect(window_, "destroy", G_CALLBACK(&ConstraintZone::OnDestroy), this);
    }
    GtkWindow* win = GTK_WINDOW(window_);
    gtk_window_resize(win, static_cast<int>(w), static_cast<int>(h));
    gtk_window_move(win, static_cast<int>(x), static_cast<int>(y));
    gtk_widget_show_all(window_);
  }

  void Hide() {
    if (window_ != nullptr) gtk_widget_destroy(window_);
  }

 private:
  static void OnDestroy(GtkWidget*, gpointer data) {
    static_cast<ConstraintZone*>(data)->window_ = nullptr;
  }

  static gboolean OnDraw(GtkWidget* widget, cairo_t* cr, gpointer) {
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

    // Dashed blue border marks the zone; the interior stays clear.
    const double dashes[] = {8, 4};
    cairo_set_dash(cr, dashes, 2, 0);
    cairo_set_line_width(cr, 2);
    cairo_set_source_rgba(cr, 0.04, 0.52, 1.0, 0.8);
    cairo_rectangle(cr, 2, 2, gtk_widget_get_allocated_width(widget) - 4,
                    gtk_widget_get_allocated_height(widget) - 4);
    cairo_stroke(cr);
    return TRUE;
  }

  static gboolean OnConfigure(GtkWidget* widget, GdkEventConfigure* event, gpointer data) {
    auto* self = static_cast<ConstraintZone*>(data);
    if (self->bounds_ == nullptr || !self->bounds_->listening()) return FALSE;
    gint x = 0, y = 0;
    gtk_window_get_position(GTK_WINDOW(widget), &x, &y);
    FlValue* map = fl_value_new_map();
    SetNum(map, "x", x);
    SetNum(map, "y", y);
    SetNum(map, "width", event->width);
    SetNum(map, "height", event->height);
    self->bounds_->Send(map);
    return FALSE;
  }

  GtkWidget* window_ = nullptr;
  EventStream* bounds_ = nullptr;
};

// ---------------------------------------------------------------------------
// Streams driven by polling
// ---------------------------------------------------------------------------

class MeetingDetectionStream {
 public:
  explicit MeetingDetectionStream(FlBinaryMessenger* messenger)
      : stream_(messenger, "com.breakmate/meeting_detection", [this]() { Push(true); }) {
    g_timeout_add_seconds(2, &MeetingDetectionStream::OnTimer, this);
  }

 private:
  static gboolean OnTimer(gpointer data) {
    static_cast<MeetingDetectionStream*>(data)->Push(false);
    return G_SOURCE_CONTINUE;
  }

  void Push(bool force) {
    if (!stream_.listening()) return;
    const sys::ActiveWindow active = sys::GetActiveWindow();
    if (!active.ok) return;
    const std::string id = !active.exe_path.empty() ? active.exe_path : active.wm_class;
    const bool meeting = sys::IsMeetingApp(active.wm_class, active.exe_name);
    if (!force && id == last_id_) return;
    last_id_ = id;

    FlValue* map = fl_value_new_map();
    SetBool(map, "isMeetingAppFrontmost", meeting);
    SetStr(map, "bundleId", active.wm_class.empty() ? id : active.wm_class);
    stream_.Send(map);
  }

  EventStream stream_;
  std::string last_id_;
};

// ---------------------------------------------------------------------------
// Display changes
// ---------------------------------------------------------------------------

guint g_display_debounce = 0;

gboolean OnDisplaysSettled(gpointer) {
  g_display_debounce = 0;
  SecondaryWindows::Get().OnDisplaysChanged();

  if (g_display_events != nullptr) {
    FlValue* map = fl_value_new_map();
    SetStr(map, "type", "display_changed");
    g_display_events->Send(map);
  }
  if (g_display_change != nullptr) g_display_change->Send(DisplayList(false));
  return G_SOURCE_REMOVE;
}

void OnMonitorsChanged() {
  // Docking a laptop fires several notifications in a row; act on the last.
  if (g_display_debounce != 0) g_source_remove(g_display_debounce);
  g_display_debounce = g_timeout_add(300, &OnDisplaysSettled, nullptr);
}

void WatchDisplays() {
  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr) return;
  g_signal_connect(display, "monitor-added", G_CALLBACK(+[](GdkDisplay*, GdkMonitor*) {
                     OnMonitorsChanged();
                   }),
                   nullptr);
  g_signal_connect(display, "monitor-removed", G_CALLBACK(+[](GdkDisplay*, GdkMonitor*) {
                     OnMonitorsChanged();
                   }),
                   nullptr);
  g_signal_connect(gdk_display_get_default_screen(display), "monitors-changed",
                   G_CALLBACK(+[](GdkScreen*) { OnMonitorsChanged(); }), nullptr);
}

// ---------------------------------------------------------------------------
// App tracking
// ---------------------------------------------------------------------------

void RegisterAppTracking(FlBinaryMessenger* messenger) {
  NewMethodChannel(messenger, "com.breakmate/app_tracking", [](FlMethodCall* call) {
    const std::string method = fl_method_call_get_name(call);
    FlValue* args = fl_method_call_get_args(call);

    if (method == "getActiveApp") {
      // The window title is only read when explicitly requested; there is no
      // portable way to read a browser's address bar, so no URL is reported.
      const bool include_title = GetBool(args, "includeTitle", false);
      const sys::ActiveWindow active = sys::GetActiveWindow();
      if (!active.ok) {
        Ok(call);
        return;
      }
      const std::string fallback = !active.exe_name.empty() ? active.exe_name : active.wm_class;
      g_autoptr(FlValue) map = fl_value_new_map();
      SetStr(map, "name", (include_title && !active.title.empty()) ? active.title : fallback);
      SetStr(map, "bundleId", !active.exe_path.empty() ? active.exe_path : active.wm_class);
      SetStr(map, "executableName", fallback);
      Ok(call, map);
    } else if (method == "getAppIcon") {
      std::string id = Str(args, "bundleId");
      std::string exe = Str(args, "executableName");
      if (exe.empty() && !id.empty()) {
        gchar* base = g_path_get_basename(id.c_str());
        exe = base;
        g_free(base);
      }
      std::vector<unsigned char> png = sys::GetAppIconPng("", exe);
      if (png.empty()) {
        Ok(call);
      } else {
        g_autoptr(FlValue) bytes = fl_value_new_uint8_list(png.data(), png.size());
        Ok(call, bytes);
      }
    } else {
      NotImplemented(call);
    }
  });
}

// ---------------------------------------------------------------------------
// The main window's desktop bridge
// ---------------------------------------------------------------------------

void HandleMainBridgeCall(FlMethodCall* call) {
  if (HandleSystemCall(call, true)) return;

  const std::string method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  SecondaryWindows& windows = SecondaryWindows::Get();

  if (method == "focusApp") {
    gtk_window_present(g_main_window);
    Ok(call);
  } else if (method == "setWindowLevel") {
    gtk_window_set_keep_above(g_main_window, Str(args, "level") != "normal");
    Ok(call);
  } else if (method == "setIgnoreMouseEvents") {
    SetClickThrough(GTK_WIDGET(g_main_window), GetBool(args, "ignore", false));
    Ok(call);
  } else if (method == "showOverlay") {
    windows.ShowOverlay(args);
    Ok(call);
  } else if (method == "updateOverlayData") {
    windows.UpdateOverlay(args);
    Ok(call);
  } else if (method == "hideOverlay" || method == "skipBreak" || method == "completeBreak") {
    windows.HideOverlay();
    Ok(call);
  } else if (method == "showCompanion") {
    windows.ShowCompanion(args);
    Ok(call);
  } else if (method == "hideCompanion") {
    windows.HideCompanion();
    Ok(call);
  } else if (method == "setCompanionClickThrough") {
    g_autoptr(FlValue) params = fl_value_new_map();
    SetBool(params, "clickThrough", GetBool(args, "ignore", false));
    windows.UpdateCompanion(params);
    Ok(call);
  } else if (method.find("updateCompanion") != std::string::npos ||
             method == "triggerCompanionState" || method == "setCompanionWandering" ||
             method == "setCompanionFollowMouse") {
    windows.UpdateCompanion(args);
    Ok(call);
  } else if (method == "showPipWindow") {
    windows.ShowPip(args);
    Ok(call);
  } else if (method == "hidePipWindow") {
    windows.HidePip();
    Ok(call);
  } else {
    // Calendar access has no Linux backend; Dart treats this as "unavailable".
    NotImplemented(call);
  }
}

}  // namespace

// ---------------------------------------------------------------------------
// Shared with secondary engines
// ---------------------------------------------------------------------------

bool HandleSystemCall(FlMethodCall* call, bool is_main_engine) {
  const std::string method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);

  if (method == "checkIsMainEngine") {
    g_autoptr(FlValue) v = fl_value_new_bool(is_main_engine);
    Ok(call, v);
  } else if (method == "getIdleTime") {
    g_autoptr(FlValue) v = fl_value_new_float(sys::GetIdleSeconds());
    Ok(call, v);
  } else if (method == "getAppearance") {
    g_autoptr(FlValue) v = fl_value_new_string(sys::GetAppearance().c_str());
    Ok(call, v);
  } else if (method == "getCursorPosition") {
    double x = 0, y = 0;
    if (!sys::GetCursorPosition(&x, &y)) {
      Fail(call, "CURSOR_ERROR", "Failed to get cursor position");
      return true;
    }
    g_autoptr(FlValue) map = fl_value_new_map();
    SetNum(map, "x", x);
    SetNum(map, "y", y);
    Ok(call, map);
  } else if (method == "getVisibleWindows") {
    g_autoptr(FlValue) list = fl_value_new_list();
    for (const sys::WindowRect& w : sys::GetVisibleWindows()) {
      FlValue* map = fl_value_new_map();
      fl_value_set_string_take(map, "windowId", fl_value_new_int(static_cast<int64_t>(w.id)));
      SetStr(map, "appBundleId", w.wm_class);
      SetStr(map, "windowTitle", w.title);
      SetNum(map, "x", w.x);
      SetNum(map, "y", w.y);
      SetNum(map, "width", w.width);
      SetNum(map, "height", w.height);
      SetBool(map, "isMinimized", w.minimized);
      SetBool(map, "isVisible", !w.minimized);
      fl_value_append_take(list, map);
    }
    Ok(call, list);
  } else if (method == "enumerateDisplays") {
    g_autoptr(FlValue) list = DisplayList(false);
    Ok(call, list);
  } else if (method == "showConstraintWindow") {
    ConstraintZone::Get().Show(Num(args, "x", 100), Num(args, "y", 100), Num(args, "width", 300),
                               Num(args, "height", 300));
    Ok(call);
  } else if (method == "hideConstraintWindow") {
    ConstraintZone::Get().Hide();
    Ok(call);
  } else {
    return false;
  }
  return true;
}

DisplayChannels NewDisplayChannels(FlBinaryMessenger* messenger, bool is_main_engine) {
  DisplayChannels out;
  out.method = NewMethodChannel(messenger, "com.breakmate/display_bridge", [](FlMethodCall* call) {
    if (std::string(fl_method_call_get_name(call)) == "getDisplays") {
      g_autoptr(FlValue) list = DisplayList(true);
      Ok(call, list);
    } else {
      NotImplemented(call);
    }
  });
  // The stream only signals that something changed; Dart re-enumerates.
  out.events.reset(new EventStream(messenger, "com.breakmate/display_events"));
  if (is_main_engine) g_display_events = out.events.get();
  return out;
}

void RegisterMainBridges(FlView* view, GtkWindow* window) {
  g_main_window = window;
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(fl_view_get_engine(view));

  // All of these live for the whole process, so they are never released.
  FlMethodChannel* bridge =
      NewMethodChannel(messenger, "com.breakmate.desktop/bridge", HandleMainBridgeCall);
  SecondaryWindows::Get().SetMainBridge(bridge);

  NewMethodChannel(messenger, "com.breakmate/overlay", [](FlMethodCall* call) {
    if (std::string(fl_method_call_get_name(call)) != "setStrictMode") {
      NotImplemented(call);
      return;
    }
    FlValue* args = fl_method_call_get_args(call);
    const bool enabled = fl_value_get_type(args) == FL_VALUE_TYPE_BOOL && fl_value_get_bool(args);
    gtk_window_set_keep_above(g_main_window, enabled);
    if (enabled) gtk_window_present(g_main_window);
    Ok(call);
  });

  NewWindowChannel(messenger, GTK_WIDGET(window));
  IpcHub::Get().Add(view, messenger);
  RegisterAppTracking(messenger);

  DisplayChannels display = NewDisplayChannels(messenger, true);
  display.events.release();  // g_display_events keeps pointing at it
  g_display_change = new EventStream(messenger, "com.breakmate.desktop/displayChange");
  ConstraintZone::Get().SetBoundsStream(
      new EventStream(messenger, "com.breakmate.desktop/constraintWindowBounds"));

  new MeetingDetectionStream(messenger);
  RegisterEnhancements(messenger);
  RegisterSmartDetection(messenger);

  WatchDisplays();
}

}  // namespace bm
