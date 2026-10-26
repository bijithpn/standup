#ifndef RUNNER_WINDOW_UTIL_H_
#define RUNNER_WINDOW_UTIL_H_

#include <gtk/gtk.h>

namespace bm {

// Lets pointer events fall through to whatever is underneath. Needs a realized
// window; realizes it if necessary.
inline void SetClickThrough(GtkWidget* window, bool enabled) {
  gtk_widget_realize(window);
  GdkWindow* gdk_window = gtk_widget_get_window(window);
  if (gdk_window == nullptr) return;
  if (enabled) {
    cairo_region_t* empty = cairo_region_create();
    gdk_window_input_shape_combine_region(gdk_window, empty, 0, 0);
    cairo_region_destroy(empty);
  } else {
    gdk_window_input_shape_combine_region(gdk_window, nullptr, 0, 0);
  }
}

// Gives |window| an RGBA visual so it can be drawn with per-pixel alpha.
// Returns false when the session has no compositor.
inline bool EnableTransparency(GtkWidget* window) {
  GdkScreen* screen = gtk_widget_get_screen(window);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual == nullptr || !gdk_screen_is_composited(screen)) return false;
  gtk_widget_set_visual(window, visual);
  gtk_widget_set_app_paintable(window, TRUE);
  return true;
}

// An undecorated, always-on-top window that never takes focus: the base for
// pills, flashes and other transient overlays.
inline GtkWidget* NewTransientOverlay() {
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  GtkWindow* w = GTK_WINDOW(window);
  gtk_window_set_decorated(w, FALSE);
  gtk_window_set_keep_above(w, TRUE);
  gtk_window_set_skip_taskbar_hint(w, TRUE);
  gtk_window_set_skip_pager_hint(w, TRUE);
  gtk_window_set_accept_focus(w, FALSE);
  gtk_window_set_focus_on_map(w, FALSE);
  gtk_window_set_type_hint(w, GDK_WINDOW_TYPE_HINT_NOTIFICATION);
  gtk_window_stick(w);
  EnableTransparency(window);
  SetClickThrough(window, true);
  return window;
}

// Monitor under the pointer, falling back to the primary one.
inline GdkMonitor* MonitorAt(int x, int y) {
  GdkDisplay* display = gdk_display_get_default();
  GdkMonitor* monitor = gdk_display_get_monitor_at_point(display, x, y);
  return monitor != nullptr ? monitor : gdk_display_get_primary_monitor(display);
}

}  // namespace bm

#endif  // RUNNER_WINDOW_UTIL_H_
