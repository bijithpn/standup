#include "window_channel.h"

#include <memory>
#include <string>

#include "bridge_util.h"
#include "system_info.h"
#include "window_util.h"

namespace bm {
namespace {

// Tracks a widget without keeping it alive.
struct WeakWindow {
  GtkWidget* widget;
  explicit WeakWindow(GtkWidget* w) : widget(w) {
    g_object_add_weak_pointer(G_OBJECT(w), reinterpret_cast<gpointer*>(&widget));
  }
  ~WeakWindow() {
    if (widget != nullptr) {
      g_object_remove_weak_pointer(G_OBJECT(widget), reinterpret_cast<gpointer*>(&widget));
    }
  }
};

void BeginDrag(GtkWindow* window) {
  double px = 0, py = 0;
  if (!sys::GetCursorPosition(&px, &py)) return;
  // The call arrives asynchronously from Dart, so there is no live button event
  // to hand over; the window manager accepts the current pointer position.
  gtk_window_begin_move_drag(window, 1, static_cast<int>(px), static_cast<int>(py),
                             GDK_CURRENT_TIME);
}

}  // namespace

FlMethodChannel* NewWindowChannel(FlBinaryMessenger* messenger, GtkWidget* window) {
  auto weak = std::make_shared<WeakWindow>(window);

  return NewMethodChannel(messenger, "com.breakmate/window", [weak](FlMethodCall* call) {
    GtkWidget* widget = weak->widget;
    const std::string method = fl_method_call_get_name(call);
    FlValue* args = fl_method_call_get_args(call);

    if (widget == nullptr) {
      if (method == "getWindowPosition") {
        FlValue* map = fl_value_new_map();
        SetNum(map, "x", 0);
        SetNum(map, "y", 0);
        SetNum(map, "width", 0);
        SetNum(map, "height", 0);
        g_autoptr(FlValue) owned = map;
        Ok(call, owned);
      } else {
        Ok(call);
      }
      return;
    }

    GtkWindow* win = GTK_WINDOW(widget);

    if (method == "setWindowLevel") {
      const std::string level = Str(args, "level");
      gtk_window_set_keep_above(win, level != "normal");
      Ok(call);
    } else if (method == "setWindowPosition") {
      if (Has(args, "x") && Has(args, "y")) {
        gtk_window_move(win, static_cast<int>(Num(args, "x", 0)),
                        static_cast<int>(Num(args, "y", 0)));
      }
      Ok(call);
    } else if (method == "getWindowPosition") {
      gint x = 0, y = 0, w = 0, h = 0;
      gtk_window_get_position(win, &x, &y);
      gtk_window_get_size(win, &w, &h);
      g_autoptr(FlValue) map = fl_value_new_map();
      SetNum(map, "x", x);
      SetNum(map, "y", y);
      SetNum(map, "width", w);
      SetNum(map, "height", h);
      Ok(call, map);
    } else if (method == "setWindowSize") {
      int w = static_cast<int>(Num(args, "width", 0));
      int h = static_cast<int>(Num(args, "height", 0));
      if (w > 0 && h > 0) gtk_window_resize(win, w, h);
      Ok(call);
    } else if (method == "setWindowOpacity") {
      gtk_widget_set_opacity(widget, Num(args, "opacity", 1.0));
      Ok(call);
    } else if (method == "setIgnoresMouseEvents") {
      SetClickThrough(widget, Bool(args, "ignore", false));
      Ok(call);
    } else if (method == "orderFrontRegardless" || method == "showWindow") {
      gtk_window_present(win);
      Ok(call);
    } else if (method == "hideWindow") {
      gtk_widget_hide(widget);
      Ok(call);
    } else if (method == "setWindowStyle") {
      // borderless / titled / utility / hud
      gtk_window_set_decorated(win, Str(args, "style") != "borderless");
      Ok(call);
    } else if (method == "startDrag") {
      BeginDrag(win);
      Ok(call);
    } else if (method == "setNonActivating") {
      bool non_activating = Bool(args, "nonActivating", false);
      gtk_window_set_accept_focus(win, !non_activating);
      gtk_window_set_focus_on_map(win, !non_activating);
      Ok(call);
    } else if (method == "setHasShadow" || method == "setAcceptsMouseMovedEvents") {
      Ok(call);  // no equivalent; the compositor decides
    } else {
      NotImplemented(call);
    }
  });
}

}  // namespace bm
