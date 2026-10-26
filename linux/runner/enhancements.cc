#include "enhancements.h"

#include <gio/gio.h>
#include <pango/pangocairo.h>

#include <algorithm>
#include <cstdlib>
#include <memory>
#include <string>
#include <vector>

#include "bridge_util.h"
#include "system_info.h"
#include "window_util.h"

namespace bm {
namespace {

// ---------------------------------------------------------------------------
// Drawing helpers
// ---------------------------------------------------------------------------

void RoundedRect(cairo_t* cr, double x, double y, double w, double h, double r) {
  r = std::min(r, std::min(w, h) / 2.0);
  cairo_new_sub_path(cr);
  cairo_arc(cr, x + w - r, y + r, r, -G_PI / 2, 0);
  cairo_arc(cr, x + w - r, y + h - r, r, 0, G_PI / 2);
  cairo_arc(cr, x + r, y + h - r, r, G_PI / 2, G_PI);
  cairo_arc(cr, x + r, y + r, r, G_PI, 3 * G_PI / 2);
  cairo_close_path(cr);
}

void ClearSurface(cairo_t* cr) {
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
  cairo_set_source_rgba(cr, 0, 0, 0, 0);
  cairo_paint(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
}

void DrawText(cairo_t* cr, const std::string& text, const char* font, double x, double y,
              double w, double h, bool centered) {
  PangoLayout* layout = pango_cairo_create_layout(cr);
  PangoFontDescription* desc = pango_font_description_from_string(font);
  pango_layout_set_font_description(layout, desc);
  pango_layout_set_text(layout, text.c_str(), -1);
  pango_layout_set_width(layout, static_cast<int>(w * PANGO_SCALE));
  pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
  pango_layout_set_alignment(layout, centered ? PANGO_ALIGN_CENTER : PANGO_ALIGN_LEFT);

  int tw = 0, th = 0;
  pango_layout_get_pixel_size(layout, &tw, &th);
  cairo_set_source_rgba(cr, 1, 1, 1, 1);
  cairo_move_to(cr, x, y + (h - th) / 2.0);
  pango_cairo_show_layout(cr, layout);

  pango_font_description_free(desc);
  g_object_unref(layout);
}

bool ParseHexColor(const std::string& hex, double* r, double* g, double* b) {
  std::string h = hex;
  if (!h.empty() && h[0] == '#') h.erase(0, 1);
  if (h.size() != 6) return false;
  char* end = nullptr;
  unsigned long v = std::strtoul(h.c_str(), &end, 16);
  if (end == h.c_str() || *end != '\0') return false;
  *r = ((v >> 16) & 0xFF) / 255.0;
  *g = ((v >> 8) & 0xFF) / 255.0;
  *b = (v & 0xFF) / 255.0;
  return true;
}

// ---------------------------------------------------------------------------
// Cursor countdown pill
// ---------------------------------------------------------------------------
class CursorCountdown {
 public:
  static CursorCountdown& Get() {
    static CursorCountdown* instance = new CursorCountdown();
    return *instance;
  }

  void Start(int seconds) {
    remaining_ = std::max(seconds, 1);
    if (window_ == nullptr) {
      window_ = NewTransientOverlay();
      gtk_window_set_default_size(GTK_WINDOW(window_), kWidth, kHeight);
      gtk_widget_set_size_request(window_, kWidth, kHeight);
      g_signal_connect(window_, "draw", G_CALLBACK(&CursorCountdown::OnDraw), this);
      g_signal_connect(window_, "destroy", G_CALLBACK(&CursorCountdown::OnDestroyed), this);
    }
    Reposition();
    gtk_widget_show_all(window_);
    gtk_widget_queue_draw(window_);

    if (track_source_ == 0) track_source_ = g_timeout_add(16, &CursorCountdown::OnTrack, this);
    if (tick_source_ == 0) tick_source_ = g_timeout_add_seconds(1, &CursorCountdown::OnTick, this);
  }

  void Dismiss() {
    if (track_source_ != 0) g_source_remove(track_source_);
    if (tick_source_ != 0) g_source_remove(tick_source_);
    track_source_ = tick_source_ = 0;
    if (window_ != nullptr) gtk_widget_destroy(window_);  // OnDestroyed clears window_
  }

 private:
  static constexpr int kWidth = 64;
  static constexpr int kHeight = 26;

  static void OnDestroyed(GtkWidget*, gpointer data) {
    static_cast<CursorCountdown*>(data)->window_ = nullptr;
  }

  static gboolean OnTrack(gpointer data) {
    auto* self = static_cast<CursorCountdown*>(data);
    self->Reposition();
    return G_SOURCE_CONTINUE;
  }

  static gboolean OnTick(gpointer data) {
    auto* self = static_cast<CursorCountdown*>(data);
    if (--self->remaining_ > 0) {
      if (self->window_ != nullptr) gtk_widget_queue_draw(self->window_);
      return G_SOURCE_CONTINUE;
    }
    self->tick_source_ = 0;  // returning REMOVE below ends this source
    self->Dismiss();
    return G_SOURCE_REMOVE;
  }

  void Reposition() {
    if (window_ == nullptr) return;
    double px = 0, py = 0;
    if (!sys::GetCursorPosition(&px, &py)) return;

    GdkMonitor* monitor = MonitorAt(static_cast<int>(px), static_cast<int>(py));
    GdkRectangle work = {0, 0, 0, 0};
    if (monitor != nullptr) gdk_monitor_get_workarea(monitor, &work);

    int x = static_cast<int>(px) + 16;
    int y = static_cast<int>(py) + 16;
    if (work.width > 0) {
      if (x + kWidth > work.x + work.width) x = static_cast<int>(px) - kWidth - 10;
      x = std::max(x, work.x + 4);
      if (y + kHeight > work.y + work.height - 4) y = static_cast<int>(py) - kHeight - 16;
      y = std::max(y, work.y + 4);
    }
    gtk_window_move(GTK_WINDOW(window_), x, y);
  }

  static gboolean OnDraw(GtkWidget*, cairo_t* cr, gpointer data) {
    auto* self = static_cast<CursorCountdown*>(data);
    ClearSurface(cr);

    RoundedRect(cr, 0.5, 0.5, kWidth - 1, kHeight - 1, kHeight / 2.0);
    cairo_set_source_rgba(cr, 0.11, 0.11, 0.12, 0.92);
    cairo_fill_preserve(cr);
    cairo_set_source_rgba(cr, 1, 1, 1, 0.2);
    cairo_set_line_width(cr, 1);
    cairo_stroke(cr);

    cairo_set_source_rgb(cr, 1.0, 0.58, 0.0);
    cairo_arc(cr, 16, kHeight / 2.0, 3, 0, 2 * G_PI);
    cairo_fill(cr);

    DrawText(cr, std::to_string(self->remaining_) + "s", "Monospace Bold 10", 26, 0, 34, kHeight,
             false);
    return TRUE;
  }

  GtkWidget* window_ = nullptr;
  guint track_source_ = 0;
  guint tick_source_ = 0;
  int remaining_ = 15;
};

// ---------------------------------------------------------------------------
// Flash reminder
// ---------------------------------------------------------------------------
struct FlashStyle {
  std::string text;
  double r = 0, g = 0, b = 0, alpha = 0.35;
};

class FlashReminder {
 public:
  static FlashReminder& Get() {
    static FlashReminder* instance = new FlashReminder();
    return *instance;
  }

  void Trigger(const std::string& text, int duration_ms, double opacity,
               const std::string& color_hex) {
    Dismiss();
    style_.text = text;
    style_.alpha = std::min(1.0, std::max(0.0, opacity));
    if (!ParseHexColor(color_hex, &style_.r, &style_.g, &style_.b)) {
      style_.r = style_.g = style_.b = 0;
    }

    GdkDisplay* display = gdk_display_get_default();
    int count = gdk_display_get_n_monitors(display);
    for (int i = 0; i < count; ++i) {
      GdkRectangle geo;
      gdk_monitor_get_geometry(gdk_display_get_monitor(display, i), &geo);

      GtkWidget* window = NewTransientOverlay();
      gtk_window_set_default_size(GTK_WINDOW(window), geo.width, geo.height);
      gtk_widget_set_size_request(window, geo.width, geo.height);
      gtk_window_move(GTK_WINDOW(window), geo.x, geo.y);
      g_signal_connect(window, "draw", G_CALLBACK(&FlashReminder::OnDraw), this);
      gtk_widget_show_all(window);
      windows_.push_back(window);
    }
    timer_ = g_timeout_add(static_cast<guint>(std::max(duration_ms, 50)),
                           &FlashReminder::OnTimeout, this);
  }

  void Dismiss() {
    if (timer_ != 0) {
      g_source_remove(timer_);
      timer_ = 0;
    }
    for (GtkWidget* w : windows_) gtk_widget_destroy(w);
    windows_.clear();
  }

 private:
  static gboolean OnTimeout(gpointer data) {
    auto* self = static_cast<FlashReminder*>(data);
    self->timer_ = 0;
    self->Dismiss();
    return G_SOURCE_REMOVE;
  }

  static gboolean OnDraw(GtkWidget* widget, cairo_t* cr, gpointer data) {
    auto* self = static_cast<FlashReminder*>(data);
    const FlashStyle& s = self->style_;
    ClearSurface(cr);

    const double w = gtk_widget_get_allocated_width(widget);
    const double h = gtk_widget_get_allocated_height(widget);
    cairo_set_source_rgba(cr, s.r, s.g, s.b, s.alpha);
    cairo_paint(cr);

    const double pill_w = std::min(540.0, w - 80.0);
    const double pill_h = 84.0;
    const double px = (w - pill_w) / 2.0;
    const double py = (h - pill_h) / 2.0;
    RoundedRect(cr, px, py, pill_w, pill_h, 24);
    cairo_set_source_rgba(cr, 0.11, 0.11, 0.12, 0.94);
    cairo_fill_preserve(cr);
    cairo_set_source_rgba(cr, 1, 1, 1, 0.25);
    cairo_set_line_width(cr, 1);
    cairo_stroke(cr);

    DrawText(cr, s.text, "Sans Bold 20", px + 24, py, pill_w - 48, pill_h, true);
    return TRUE;
  }

  std::vector<GtkWidget*> windows_;
  FlashStyle style_;
  guint timer_ = 0;
};

// ---------------------------------------------------------------------------
// Display sleep prevention
// ---------------------------------------------------------------------------
class SleepInhibitor {
 public:
  static SleepInhibitor& Get() {
    static SleepInhibitor* instance = new SleepInhibitor();
    return *instance;
  }

  void Prevent(const std::string& reason) {
    if (cookie_ != 0) return;

    g_autoptr(GError) error = nullptr;
    g_autoptr(GDBusConnection) bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
    if (bus == nullptr) return;

    // org.freedesktop.ScreenSaver is implemented by GNOME, KDE and others.
    g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
        bus, "org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver",
        "org.freedesktop.ScreenSaver", "Inhibit",
        g_variant_new("(ss)", sys::kInhibitReason, reason.c_str()), G_VARIANT_TYPE("(u)"),
        G_DBUS_CALL_FLAGS_NO_AUTO_START, 500, nullptr, nullptr);
    if (reply != nullptr) {
      g_variant_get(reply, "(u)", &cookie_);
      method_ = Method::kScreenSaver;
      return;
    }

    // flags: 8 = inhibit the session being marked idle
    g_autoptr(GVariant) gnome = g_dbus_connection_call_sync(
        bus, "org.gnome.SessionManager", "/org/gnome/SessionManager", "org.gnome.SessionManager",
        "Inhibit", g_variant_new("(susu)", sys::kInhibitReason, 0u, reason.c_str(), 8u),
        G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NO_AUTO_START, 500, nullptr, nullptr);
    if (gnome != nullptr) {
      g_variant_get(gnome, "(u)", &cookie_);
      method_ = Method::kGnomeSession;
    }
  }

  void Release() {
    if (cookie_ == 0) return;

    g_autoptr(GDBusConnection) bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, nullptr);
    if (bus != nullptr) {
      const bool screensaver = method_ == Method::kScreenSaver;
      g_autoptr(GVariant) ignored = g_dbus_connection_call_sync(
          bus, screensaver ? "org.freedesktop.ScreenSaver" : "org.gnome.SessionManager",
          screensaver ? "/org/freedesktop/ScreenSaver" : "/org/gnome/SessionManager",
          screensaver ? "org.freedesktop.ScreenSaver" : "org.gnome.SessionManager", "UnInhibit",
          g_variant_new("(u)", cookie_), nullptr, G_DBUS_CALL_FLAGS_NO_AUTO_START, 500, nullptr,
          nullptr);
    }
    cookie_ = 0;
  }

 private:
  enum class Method { kScreenSaver, kGnomeSession };
  guint cookie_ = 0;
  Method method_ = Method::kScreenSaver;
};

// ---------------------------------------------------------------------------
// Smart detection
// ---------------------------------------------------------------------------
class SmartDetector {
 public:
  explicit SmartDetector(FlBinaryMessenger* messenger)
      : stream_(messenger, "com.breakmate/smart_detection_events", [this]() { Push(); }) {
    g_timeout_add_seconds(kPollSeconds, &SmartDetector::OnPoll, this);
  }

 private:
  static constexpr guint kPollSeconds = 2;
  static constexpr gint64 kMicGraceUs = 20 * G_USEC_PER_SEC;  // survives mute toggles
  static constexpr gint64 kCameraGraceUs = 15 * G_USEC_PER_SEC;

  struct Snapshot {
    bool mic = false, camera = false, video = false, focus = false;
  };

  static gboolean OnPoll(gpointer data) {
    auto* self = static_cast<SmartDetector*>(data);
    // Nothing listens until Dart subscribes; skip the probing entirely.
    if (self->busy_ || !self->stream_.listening()) return G_SOURCE_CONTINUE;
    self->busy_ = true;

    GTask* task = g_task_new(nullptr, nullptr, &SmartDetector::OnProbed, self);
    g_task_run_in_thread(task, [](GTask* t, gpointer, gpointer, GCancellable*) {
      auto* snapshot = new Snapshot();
      snapshot->mic = sys::IsMicrophoneInUse();
      snapshot->camera = sys::IsCameraInUse();
      snapshot->video = sys::IsVideoPlaying();
      snapshot->focus = sys::IsDoNotDisturb();
      g_task_return_pointer(t, snapshot, [](gpointer p) { delete static_cast<Snapshot*>(p); });
    });
    g_object_unref(task);
    return G_SOURCE_CONTINUE;
  }

  static void OnProbed(GObject*, GAsyncResult* res, gpointer data) {
    auto* self = static_cast<SmartDetector*>(data);
    self->busy_ = false;
    std::unique_ptr<Snapshot> snapshot(
        static_cast<Snapshot*>(g_task_propagate_pointer(G_TASK(res), nullptr)));
    if (snapshot) self->Apply(*snapshot);
  }

  // Latches "active" immediately and only releases after the grace period.
  static bool Latch(bool active_now, gint64 grace_us, bool* current, gint64* last_seen) {
    const gint64 now = g_get_monotonic_time();
    if (active_now) {
      *last_seen = now;
      if (!*current) {
        *current = true;
        return true;
      }
    } else if (*current && now - *last_seen >= grace_us) {
      *current = false;
      return true;
    }
    return false;
  }

  void Apply(const Snapshot& s) {
    bool changed = false;
    changed |= Latch(s.mic, kMicGraceUs, &mic_, &mic_seen_);
    changed |= Latch(s.camera, kCameraGraceUs, &camera_, &camera_seen_);
    if (s.video != video_) {
      video_ = s.video;
      changed = true;
    }
    if (s.focus != focus_) {
      focus_ = s.focus;
      changed = true;
    }
    if (changed) Push();
  }

  void Push() {
    FlValue* map = fl_value_new_map();
    SetBool(map, "isMicrophoneActive", mic_);
    SetBool(map, "isCameraActive", camera_);
    SetBool(map, "isInMeeting", mic_ || camera_);
    SetBool(map, "isVideoPlaying", video_);
    SetBool(map, "isFocusModeActive", focus_);
    SetBool(map, "shouldPauseBreaks", mic_ || camera_ || video_ || focus_);
    stream_.Send(map);
  }

  EventStream stream_;
  bool busy_ = false;
  bool mic_ = false, camera_ = false, video_ = false, focus_ = false;
  gint64 mic_seen_ = 0, camera_seen_ = 0;
};

}  // namespace

void RegisterEnhancements(FlBinaryMessenger* messenger) {
  // Process-lifetime channel, like the windows runner's.
  NewMethodChannel(messenger, "com.breakmate/native_enhancements", [](FlMethodCall* call) {
    const std::string method = fl_method_call_get_name(call);
    FlValue* args = fl_method_call_get_args(call);

    if (method == "showCursorCountdown") {
      CursorCountdown::Get().Start(static_cast<int>(Num(args, "seconds", 15)));
      Ok(call);
    } else if (method == "hideCursorCountdown") {
      CursorCountdown::Get().Dismiss();
      Ok(call);
    } else if (method == "triggerFlashReminder") {
      std::string text = Str(args, "text");
      if (text.empty()) {
        Fail(call, "INVALID_ARGS", "text required");
        return;
      }
      FlashReminder::Get().Trigger(text, static_cast<int>(Num(args, "durationMs", 250)),
                                   Num(args, "opacity", 0.35), Str(args, "colorHex", "#000000"));
      Ok(call);
    } else if (method == "preventDisplaySleep") {
      SleepInhibitor::Get().Prevent(Str(args, "reason", "BreakMate Break Active"));
      Ok(call);
    } else if (method == "releaseDisplaySleep") {
      SleepInhibitor::Get().Release();
      Ok(call);
    } else {
      NotImplemented(call);
    }
  });
}

void RegisterSmartDetection(FlBinaryMessenger* messenger) {
  new SmartDetector(messenger);  // process lifetime
}

}  // namespace bm
