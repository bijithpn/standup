#include "secondary_windows.h"

#include <algorithm>
#include <string>

#include "bridge_util.h"
#include "bridges.h"
#include "system_info.h"
#include "window_channel.h"
#include "window_util.h"

namespace bm {
namespace {

FlValue* CopyMap(FlValue* source) {
  FlValue* copy = fl_value_new_map();
  if (source == nullptr || fl_value_get_type(source) != FL_VALUE_TYPE_MAP) return copy;
  size_t n = fl_value_get_length(source);
  for (size_t i = 0; i < n; ++i) {
    fl_value_set(copy, fl_value_get_map_key(source, i), fl_value_get_map_value(source, i));
  }
  return copy;
}

void DefaultStr(FlValue* map, const char* key, const char* value) {
  if (!Has(map, key)) SetStr(map, key, value);
}
void DefaultNum(FlValue* map, const char* key, double value) {
  if (!Has(map, key)) SetNum(map, key, value);
}
void DefaultBool(FlValue* map, const char* key, bool value) {
  if (!Has(map, key)) SetBool(map, key, value);
}

double Bound(double v, double lo, double hi) { return std::min(hi, std::max(lo, v)); }

FlBinaryMessenger* MessengerOf(FlView* view) {
  return fl_engine_get_binary_messenger(fl_view_get_engine(view));
}

GdkMonitor* MonitorByIndex(int index) {
  GdkDisplay* display = gdk_display_get_default();
  int count = gdk_display_get_n_monitors(display);
  if (count <= 0) return nullptr;
  return gdk_display_get_monitor(display, std::min(std::max(index, 0), count - 1));
}

int MonitorIndexAt(int x, int y) {
  GdkDisplay* display = gdk_display_get_default();
  GdkMonitor* target = MonitorAt(x, y);
  int count = gdk_display_get_n_monitors(display);
  for (int i = 0; i < count; ++i) {
    if (gdk_display_get_monitor(display, i) == target) return i;
  }
  return 0;
}

bool SameRect(const GdkRectangle& a, const GdkRectangle& b) {
  return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
}

}  // namespace

// ---------------------------------------------------------------------------
// IpcHub
// ---------------------------------------------------------------------------

IpcHub& IpcHub::Get() {
  static IpcHub* instance = new IpcHub();
  return *instance;
}

void IpcHub::Add(const void* key, FlBinaryMessenger* messenger) {
  if (channels_.count(key) != 0) return;
  channels_[key] = NewMethodChannel(messenger, "com.breakmate/ipc", [this, key](FlMethodCall* call) {
    if (std::string(fl_method_call_get_name(call)) != "sendEvent") {
      NotImplemented(call);
      return;
    }
    FlValue* args = fl_method_call_get_args(call);
    const std::string event = Str(args, "event");
    FlValue* data = Lookup(args, "data");
    if (!event.empty()) {
      // The sender has already applied the change locally; only relay it.
      for (const auto& entry : channels_) {
        if (entry.first != key) Invoke(entry.second, event.c_str(), data);
      }
    }
    Ok(call);
  });
}

void IpcHub::Remove(const void* key) {
  auto it = channels_.find(key);
  if (it == channels_.end()) return;
  g_object_unref(it->second);
  channels_.erase(it);
}

// ---------------------------------------------------------------------------
// SecondaryWindows: surfaces
// ---------------------------------------------------------------------------

SecondaryWindows& SecondaryWindows::Get() {
  static SecondaryWindows* instance = new SecondaryWindows();
  return *instance;
}

SecondaryWindows::Surface* SecondaryWindows::NewSurface(const char* role) {
  auto* surface = new Surface();

  surface->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  GtkWindow* window = GTK_WINDOW(surface->window);
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_keep_above(window, TRUE);
  gtk_window_set_skip_taskbar_hint(window, TRUE);
  gtk_window_set_skip_pager_hint(window, TRUE);
  gtk_window_set_title(window, "BreakMate");
  gtk_window_stick(window);
  EnableTransparency(surface->window);
  g_signal_connect(surface->window, "delete-event", G_CALLBACK(&SecondaryWindows::OnDeleteEvent),
                   nullptr);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  gchar* role_arg = g_strdup_printf("--breakmate-role=%s", role);
  gchar* argv[] = {role_arg, nullptr};
  fl_dart_project_set_dart_entrypoint_arguments(project, argv);
  g_free(role_arg);

  surface->view = fl_view_new(project);
  GdkRGBA clear = {0, 0, 0, 0};
  fl_view_set_background_color(surface->view, &clear);
  gtk_widget_show(GTK_WIDGET(surface->view));
  gtk_container_add(GTK_CONTAINER(surface->window), GTK_WIDGET(surface->view));
  g_signal_connect(surface->view, "first-frame", G_CALLBACK(&SecondaryWindows::OnFirstFrame),
                   surface);

  // Realizing starts rendering; the window stays hidden until the first frame.
  gtk_widget_realize(GTK_WIDGET(surface->view));

  IpcHub::Get().Add(surface, MessengerOf(surface->view));
  return surface;
}

void SecondaryWindows::DestroySurface(Surface* surface) {
  if (surface == nullptr) return;
  IpcHub::Get().Remove(surface);
  for (FlMethodChannel* channel : surface->channels) g_object_unref(channel);
  surface->channels.clear();
  surface->streams.clear();
  surface->bridge = nullptr;
  surface->data = nullptr;
  if (surface->window != nullptr) gtk_widget_destroy(surface->window);
  delete surface;
}

void SecondaryWindows::OnFirstFrame(FlView*, gpointer data) {
  auto* surface = static_cast<Surface*>(data);
  if (surface->want_visible) gtk_widget_show(surface->window);
}

void SecondaryWindows::PlaceOnMonitor(Surface* surface, int monitor_index, bool fullscreen) {
  GdkMonitor* monitor = MonitorByIndex(monitor_index);
  if (monitor == nullptr) return;
  GdkRectangle geo;
  gdk_monitor_get_geometry(monitor, &geo);

  surface->monitor = monitor_index;
  surface->geometry = geo;

  GtkWindow* window = GTK_WINDOW(surface->window);
  gtk_window_unfullscreen(window);
  gtk_window_set_default_size(window, geo.width, geo.height);
  gtk_window_resize(window, geo.width, geo.height);
  gtk_window_move(window, geo.x, geo.y);
  if (fullscreen) {
    // A fullscreen window is opaque to the compositor (it may skip compositing
    // for it altogether), so only the solid break screen takes this path.
    gtk_window_fullscreen_on_monitor(window, gtk_window_get_screen(window), monitor_index);
  }
}

// ---------------------------------------------------------------------------
// Break overlay
// ---------------------------------------------------------------------------

void SecondaryWindows::AddOverlayChannels(Surface* surface) {
  FlBinaryMessenger* messenger = MessengerOf(surface->view);

  surface->bridge = NewMethodChannel(
      messenger, "com.breakmate.desktop/bridge", [this, surface](FlMethodCall* call) {
        const std::string method = fl_method_call_get_name(call);
        FlValue* args = fl_method_call_get_args(call);

        if (method == "getOverlayData") {
          Ok(call, last_overlay_args_);
        } else if (method == "checkIsMainEngine") {
          g_autoptr(FlValue) no = fl_value_new_bool(false);
          Ok(call, no);
        } else if (method == "hideOverlay") {
          HideOverlay();
          Ok(call);
        } else if (method == "skipBreak" || method == "completeBreak") {
          ForwardToMain(method.c_str());
          HideOverlay();
          Ok(call);
        } else if (method == "setIgnoreMouseEvents") {
          SetClickThrough(surface->window, Bool(args, "ignore", false));
          Ok(call);
        } else {
          NotImplemented(call);
        }
      });
  surface->channels.push_back(surface->bridge);

  surface->channels.push_back(
      NewMethodChannel(messenger, "com.breakmate/overlay", [surface](FlMethodCall* call) {
        if (std::string(fl_method_call_get_name(call)) == "setStrictMode") {
          FlValue* args = fl_method_call_get_args(call);
          bool strict = fl_value_get_type(args) == FL_VALUE_TYPE_BOOL && fl_value_get_bool(args);
          gtk_window_set_keep_above(GTK_WINDOW(surface->window), TRUE);
          if (strict) gtk_window_present(GTK_WINDOW(surface->window));
          Ok(call);
        } else {
          NotImplemented(call);
        }
      }));

  g_signal_connect(surface->window, "key-press-event",
                   G_CALLBACK(&SecondaryWindows::OnOverlayKey), this);
}

gboolean SecondaryWindows::OnOverlayKey(GtkWidget*, GdkEventKey* event, gpointer data) {
  auto* self = static_cast<SecondaryWindows*>(data);
  // The overlay may not have keyboard focus, and a strict break cannot be
  // dismissed at all.
  if (event->keyval == GDK_KEY_Escape && !self->overlays_.empty() && !self->overlay_strict_) {
    self->ForwardToMain("skipBreak");
    self->HideOverlay();
  }
  return FALSE;  // Dart still sees the key
}

void SecondaryWindows::ForwardToMain(const char* method) {
  g_autoptr(FlValue) empty = fl_value_new_map();
  Invoke(main_bridge_, method, empty);
}

void SecondaryWindows::ShowOverlay(FlValue* args) {
  if (!overlays_.empty()) return;  // a break overlay is already up

  if (last_overlay_args_ != nullptr) fl_value_unref(last_overlay_args_);
  last_overlay_args_ = fl_value_ref(args);

  const bool ignore_mouse = Bool(args, "ignoreMouseEvents", false);
  const bool all_displays = Bool(args, "showOnAllDisplays", true);
  const bool transparent = Bool(args, "isTransparent", false);
  overlay_strict_ = Bool(args, "strictMode", false);

  GdkDisplay* display = gdk_display_get_default();
  GdkMonitor* primary = gdk_display_get_primary_monitor(display);
  const int count = gdk_display_get_n_monitors(display);

  for (int i = 0; i < count; ++i) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    if (!all_displays && monitor != primary && !(primary == nullptr && i == 0)) continue;

    GdkRectangle geo;
    gdk_monitor_get_geometry(monitor, &geo);

    Surface* surface = nullptr;
    for (auto it = overlay_pool_.begin(); it != overlay_pool_.end(); ++it) {
      if ((*it)->monitor == i && SameRect((*it)->geometry, geo)) {
        surface = *it;
        overlay_pool_.erase(it);
        break;
      }
    }
    const bool warm = surface != nullptr;
    if (!warm) {
      surface = NewSurface("overlay");
      AddOverlayChannels(surface);
    }

    GtkWindow* window = GTK_WINDOW(surface->window);
    gtk_window_set_type_hint(window, transparent ? GDK_WINDOW_TYPE_HINT_NOTIFICATION
                                                 : GDK_WINDOW_TYPE_HINT_NORMAL);
    gtk_window_set_accept_focus(window, !ignore_mouse);
    gtk_window_set_focus_on_map(window, overlay_strict_);
    SetClickThrough(surface->window, ignore_mouse);
    PlaceOnMonitor(surface, i, !transparent);

    if (warm) {
      // The engine is already running, so hand it the fresh data straight away.
      Invoke(surface->bridge, "updateOverlayData", args);
      surface->want_visible = true;
      gtk_widget_show(surface->window);
    } else {
      surface->want_visible = true;
    }
    if (overlay_strict_) gtk_window_present(window);
    overlays_.push_back(surface);
  }

  // A cold engine may register its handlers after the window is up, so push the
  // payload again once it has had time to start.
  if (overlay_push_source_ != 0) g_source_remove(overlay_push_source_);
  overlay_push_source_ = g_timeout_add(1000, &SecondaryWindows::OnPushOverlayData, this);
}

gboolean SecondaryWindows::OnPushOverlayData(gpointer data) {
  auto* self = static_cast<SecondaryWindows*>(data);
  self->overlay_push_source_ = 0;
  if (self->last_overlay_args_ != nullptr) self->UpdateOverlay(self->last_overlay_args_);
  return G_SOURCE_REMOVE;
}

void SecondaryWindows::UpdateOverlay(FlValue* args) {
  for (Surface* surface : overlays_) Invoke(surface->bridge, "updateOverlayData", args);
}

void SecondaryWindows::HideOverlay() {
  if (overlays_.empty()) return;
  if (overlay_push_source_ != 0) {
    g_source_remove(overlay_push_source_);
    overlay_push_source_ = 0;
  }
  // Keep the engines alive but hidden; they are only rebuilt when the monitor
  // layout changes or the app quits.
  for (Surface* surface : overlays_) {
    surface->want_visible = false;
    gtk_widget_hide(surface->window);
    overlay_pool_.push_back(surface);
  }
  overlays_.clear();
}

void SecondaryWindows::ClearPool() {
  for (Surface* surface : overlay_pool_) DestroySurface(surface);
  overlay_pool_.clear();
}

void SecondaryWindows::OnDisplaysChanged() {
  // Pooled windows have stale geometry. An active overlay is rebuilt against the
  // new layout so it keeps covering every screen.
  const bool was_active = !overlays_.empty();
  FlValue* args = nullptr;
  if (was_active && last_overlay_args_ != nullptr) args = fl_value_ref(last_overlay_args_);

  for (Surface* surface : overlays_) DestroySurface(surface);
  overlays_.clear();
  ClearPool();

  if (args != nullptr) {
    ShowOverlay(args);
    fl_value_unref(args);
  }

  if (companion_ != nullptr) FollowPointerMonitor();
}

// ---------------------------------------------------------------------------
// Companion (a transparent, monitor-sized layer the pet roams around in)
// ---------------------------------------------------------------------------

void SecondaryWindows::AddCompanionChannels(Surface* surface, FlValue* initial_settings,
                                            const char* data_name) {
  FlBinaryMessenger* messenger = MessengerOf(surface->view);

  surface->bridge = NewMethodChannel(
      messenger, "com.breakmate.desktop/bridge", [surface](FlMethodCall* call) {
        const std::string method = fl_method_call_get_name(call);
        FlValue* args = fl_method_call_get_args(call);
        if (HandleSystemCall(call, false)) return;
        if (method == "setIgnoreMouseEvents") {
          SetClickThrough(surface->window, Bool(args, "ignore", false));
          Ok(call);
        } else {
          NotImplemented(call);
        }
      });
  surface->channels.push_back(surface->bridge);

  // Kept alive as long as the surface; the settings are shared with the handler.
  FlValue* settings = fl_value_ref(initial_settings);
  surface->data = NewMethodChannel(messenger, data_name, [settings](FlMethodCall* call) {
    if (std::string(fl_method_call_get_name(call)) == "getInitialSettings") {
      Ok(call, settings);
    } else {
      NotImplemented(call);
    }
  });
  g_object_set_data_full(G_OBJECT(surface->data), "settings", settings,
                         reinterpret_cast<GDestroyNotify>(fl_value_unref));
  surface->channels.push_back(surface->data);

  surface->channels.push_back(NewWindowChannel(messenger, surface->window));
  DisplayChannels display = NewDisplayChannels(messenger, false);
  surface->channels.push_back(display.method);
  surface->streams.push_back(std::move(display.events));
}

void SecondaryWindows::ShowCompanion(FlValue* args) {
  const std::string theme = Str(args, "themeId", "grey_cat");
  const std::string pet = Str(args, "petName", "Mochi");
  const double scale = Num(args, "scale", 6.0);
  const bool click_through = Bool(args, "clickThrough", false);

  if (companion_ != nullptr) {
    UpdateCompanion(args);
    return;
  }

  g_autoptr(FlValue) settings = fl_value_new_map();
  SetStr(settings, "themeId", theme);
  SetStr(settings, "petName", pet);
  SetNum(settings, "scale", scale);
  SetBool(settings, "clickThrough", click_through);

  companion_click_through_ = click_through;
  companion_follow_mouse_ = false;

  companion_ = NewSurface("companion");
  AddCompanionChannels(companion_, settings, "com.breakmate.desktop/companion_data");

  double px = 0, py = 0;
  sys::GetCursorPosition(&px, &py);
  PlaceOnMonitor(companion_, MonitorIndexAt(static_cast<int>(px), static_cast<int>(py)), false);
  gtk_window_set_type_hint(GTK_WINDOW(companion_->window), GDK_WINDOW_TYPE_HINT_NOTIFICATION);
  gtk_window_set_accept_focus(GTK_WINDOW(companion_->window), FALSE);
  gtk_window_set_focus_on_map(GTK_WINDOW(companion_->window), FALSE);
  SetClickThrough(companion_->window, click_through);
  companion_->want_visible = true;

  companion_mouse_source_ = g_timeout_add(16, &SecondaryWindows::OnCompanionMouse, this);
  companion_monitor_source_ = g_timeout_add(500, &SecondaryWindows::OnCompanionMonitor, this);
}

gboolean SecondaryWindows::OnCompanionMouse(gpointer data) {
  static_cast<SecondaryWindows*>(data)->SyncCompanionMouse();
  return G_SOURCE_CONTINUE;
}

gboolean SecondaryWindows::OnCompanionMonitor(gpointer data) {
  static_cast<SecondaryWindows*>(data)->FollowPointerMonitor();
  return G_SOURCE_CONTINUE;
}

void SecondaryWindows::SyncCompanionMouse() {
  if (companion_ == nullptr || companion_->data == nullptr) return;
  double px = 0, py = 0;
  if (!sys::GetCursorPosition(&px, &py)) return;

  gint wx = 0, wy = 0;
  gtk_window_get_position(GTK_WINDOW(companion_->window), &wx, &wy);

  g_autoptr(FlValue) follow = fl_value_new_map();
  SetBool(follow, "enabled", companion_follow_mouse_);
  SetNum(follow, "mouseX", px - wx);
  SetNum(follow, "mouseY", py - wy);
  g_autoptr(FlValue) payload = fl_value_new_map();
  fl_value_set_string(payload, "mouseFollow", follow);
  Invoke(companion_->data, "syncCompanionSettings", payload);
}

// Keeps the layer on whichever monitor the pointer is on.
void SecondaryWindows::FollowPointerMonitor() {
  if (companion_ == nullptr) return;
  double px = 0, py = 0;
  if (!sys::GetCursorPosition(&px, &py)) return;

  const int index = MonitorIndexAt(static_cast<int>(px), static_cast<int>(py));
  GdkMonitor* monitor = MonitorByIndex(index);
  if (monitor == nullptr) return;
  GdkRectangle geo;
  gdk_monitor_get_geometry(monitor, &geo);
  if (index != companion_->monitor || !SameRect(geo, companion_->geometry)) {
    PlaceOnMonitor(companion_, index, false);
  }
}

void SecondaryWindows::UpdateCompanion(FlValue* params) {
  if (companion_ == nullptr) return;

  if (Has(params, "clickThrough")) {
    const bool ct = Bool(params, "clickThrough", companion_click_through_);
    if (ct != companion_click_through_) {
      companion_click_through_ = ct;
      SetClickThrough(companion_->window, ct);
    }
  }
  if (Has(params, "followMouse")) {
    companion_follow_mouse_ = Bool(params, "followMouse", companion_follow_mouse_);
  }
  Invoke(companion_->data, "syncCompanionSettings", params);
}

void SecondaryWindows::HideCompanion() {
  if (companion_ == nullptr) return;
  if (companion_mouse_source_ != 0) g_source_remove(companion_mouse_source_);
  if (companion_monitor_source_ != 0) g_source_remove(companion_monitor_source_);
  companion_mouse_source_ = companion_monitor_source_ = 0;
  DestroySurface(companion_);
  companion_ = nullptr;
}

// ---------------------------------------------------------------------------
// Picture-in-picture pet
// ---------------------------------------------------------------------------

void SecondaryWindows::ShowPip(FlValue* args) {
  const bool has_position = Has(args, "x") && Has(args, "y");
  const bool has_size = Has(args, "width") && Has(args, "height");
  const int x = static_cast<int>(Num(args, "x", 100));
  const int y = static_cast<int>(Num(args, "y", 100));
  const int w = static_cast<int>(Bound(Num(args, "width", 280), 180, 360));
  const int h = static_cast<int>(Bound(Num(args, "height", 320), 210, 420));
  const bool click_through = Bool(args, "clickThrough", false);

  if (pip_ != nullptr) {
    // Settings updates reuse this call without geometry; leave a window the
    // user has dragged where it is.
    GtkWindow* window = GTK_WINDOW(pip_->window);
    if (has_size) gtk_window_resize(window, w, h);
    if (has_position) gtk_window_move(window, x, y);
    gtk_widget_show(pip_->window);
    Invoke(pip_->data, "syncPiPSettings", args);
    return;
  }

  // The PiP engine reads these from getInitialSettings; anything the caller did
  // not send falls back to the same defaults the other desktops use.
  FlValue* settings = CopyMap(args);
  DefaultStr(settings, "themeId", "grey_cat");
  DefaultStr(settings, "petName", "Mochi");
  DefaultNum(settings, "scale", 3.0);
  DefaultBool(settings, "clickThrough", false);
  DefaultStr(settings, "companionToyType", "tennis_ball");
  DefaultStr(settings, "companionTreatType", "sushi");
  DefaultStr(settings, "previewBackground", "assets/background/forest/background.png");
  DefaultStr(settings, "pipBackgroundStyle", "dark");
  DefaultNum(settings, "pipOpacity", 1.0);
  DefaultBool(settings, "wanderingEnabled", true);
  DefaultStr(settings, "avatarDefinitionJson", "");
  DefaultStr(settings, "renderMode", "");
  DefaultBool(settings, "pipDraggableClickable", true);
  DefaultBool(settings, "keepOnScreen", true);
  DefaultBool(settings, "pettingEnabled", true);
  DefaultBool(settings, "playEnabled", true);
  DefaultBool(settings, "treatEnabled", true);

  pip_ = NewSurface("pip");
  AddCompanionChannels(pip_, settings, "com.breakmate.desktop/pip_data");
  fl_value_unref(settings);

  GtkWindow* window = GTK_WINDOW(pip_->window);
  gtk_window_set_type_hint(window, GDK_WINDOW_TYPE_HINT_UTILITY);
  gtk_window_set_accept_focus(window, FALSE);
  gtk_window_set_focus_on_map(window, FALSE);
  gtk_window_set_default_size(window, w, h);
  gtk_window_resize(window, w, h);
  gtk_window_move(window, x, y);
  if (click_through) SetClickThrough(pip_->window, true);
  pip_->want_visible = true;
}

void SecondaryWindows::HidePip() {
  if (pip_ == nullptr) return;
  DestroySurface(pip_);
  pip_ = nullptr;
}

}  // namespace bm
