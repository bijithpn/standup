#include "system_info.h"

#include <glob.h>
#include <gio/gio.h>
#include <unistd.h>

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <cstring>

#ifdef GDK_WINDOWING_X11
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <gdk/gdkx.h>
#endif

namespace bm {
namespace sys {

const char kInhibitReason[] = "BreakMate";

namespace {

std::string Lower(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

bool Contains(const std::string& haystack, const char* needle) {
  return haystack.find(needle) != std::string::npos;
}

#ifdef GDK_WINDOWING_X11

Display* XDisplay() {
  GdkDisplay* d = gdk_display_get_default();
  if (d == nullptr || !GDK_IS_X11_DISPLAY(d)) return nullptr;
  return GDK_DISPLAY_XDISPLAY(d);
}

Atom GetAtom(Display* dpy, const char* name) { return XInternAtom(dpy, name, False); }

// Reads a window property into a byte buffer owned by Xlib (free with XFree).
unsigned char* ReadProperty(Display* dpy, Window win, const char* prop, Atom type,
                            unsigned long* count) {
  Atom actual_type = 0;
  int format = 0;
  unsigned long n = 0, after = 0;
  unsigned char* data = nullptr;
  int rc = XGetWindowProperty(dpy, win, GetAtom(dpy, prop), 0, 4096, False, type, &actual_type,
                              &format, &n, &after, &data);
  if (rc != Success || data == nullptr || n == 0) {
    if (data != nullptr) XFree(data);
    *count = 0;
    return nullptr;
  }
  *count = n;
  return data;
}

std::string WindowTitle(Display* dpy, Window win) {
  unsigned long n = 0;
  unsigned char* data = ReadProperty(dpy, win, "_NET_WM_NAME", GetAtom(dpy, "UTF8_STRING"), &n);
  if (data == nullptr) {
    data = ReadProperty(dpy, win, "WM_NAME", AnyPropertyType, &n);
  }
  if (data == nullptr) return std::string();
  std::string out(reinterpret_cast<char*>(data));
  XFree(data);
  return out;
}

std::string WindowClass(Display* dpy, Window win) {
  XClassHint hint = {nullptr, nullptr};
  std::string out;
  if (XGetClassHint(dpy, win, &hint)) {
    if (hint.res_class != nullptr) out = hint.res_class;
    if (hint.res_name != nullptr) XFree(hint.res_name);
    if (hint.res_class != nullptr) XFree(hint.res_class);
  }
  return Lower(out);
}

long WindowPid(Display* dpy, Window win) {
  unsigned long n = 0;
  unsigned char* data = ReadProperty(dpy, win, "_NET_WM_PID", XA_CARDINAL, &n);
  if (data == nullptr) return -1;
  long pid = *reinterpret_cast<long*>(data);
  XFree(data);
  return pid;
}

bool HasState(Display* dpy, Window win, const char* state_name) {
  unsigned long n = 0;
  unsigned char* data = ReadProperty(dpy, win, "_NET_WM_STATE", XA_ATOM, &n);
  if (data == nullptr) return false;
  Atom want = GetAtom(dpy, state_name);
  bool found = false;
  Atom* atoms = reinterpret_cast<Atom*>(data);
  for (unsigned long i = 0; i < n; ++i) {
    if (atoms[i] == want) {
      found = true;
      break;
    }
  }
  XFree(data);
  return found;
}

bool IsNormalWindowType(Display* dpy, Window win) {
  unsigned long n = 0;
  unsigned char* data = ReadProperty(dpy, win, "_NET_WM_WINDOW_TYPE", XA_ATOM, &n);
  if (data == nullptr) return true;  // untyped windows are normal
  Atom normal = GetAtom(dpy, "_NET_WM_WINDOW_TYPE_NORMAL");
  Atom dialog = GetAtom(dpy, "_NET_WM_WINDOW_TYPE_DIALOG");
  bool ok = false;
  Atom* atoms = reinterpret_cast<Atom*>(data);
  for (unsigned long i = 0; i < n; ++i) {
    if (atoms[i] == normal || atoms[i] == dialog) ok = true;
  }
  XFree(data);
  return ok;
}

#endif  // GDK_WINDOWING_X11

// Synchronous D-Bus call with a short timeout; returns nullptr on any failure.
GVariant* CallSync(GBusType bus, const char* name, const char* path, const char* iface,
                   const char* method, GVariant* params) {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) conn = g_bus_get_sync(bus, nullptr, &error);
  if (conn == nullptr) {
    if (params != nullptr) g_variant_unref(g_variant_ref_sink(params));
    return nullptr;
  }
  return g_dbus_connection_call_sync(conn, name, path, iface, method, params, nullptr,
                                     G_DBUS_CALL_FLAGS_NO_AUTO_START, 300, nullptr, &error);
}

std::string ReadFileToString(const char* path) {
  gchar* contents = nullptr;
  gsize length = 0;
  std::string out;
  if (g_file_get_contents(path, &contents, &length, nullptr)) {
    out.assign(contents, length);
    g_free(contents);
  }
  return out;
}

}  // namespace

bool IsX11() {
#ifdef GDK_WINDOWING_X11
  return XDisplay() != nullptr;
#else
  return false;
#endif
}

ActiveWindow GetActiveWindow() {
  ActiveWindow out;
#ifdef GDK_WINDOWING_X11
  Display* dpy = XDisplay();
  if (dpy == nullptr) return out;

  unsigned long n = 0;
  unsigned char* data =
      ReadProperty(dpy, DefaultRootWindow(dpy), "_NET_ACTIVE_WINDOW", XA_WINDOW, &n);
  if (data == nullptr) return out;
  Window win = *reinterpret_cast<Window*>(data);
  XFree(data);
  if (win == 0) return out;

  out.wm_class = WindowClass(dpy, win);
  out.title = WindowTitle(dpy, win);

  long pid = WindowPid(dpy, win);
  if (pid > 0) {
    gchar* link = g_strdup_printf("/proc/%ld/exe", pid);
    gchar* target = g_file_read_link(link, nullptr);
    g_free(link);
    if (target != nullptr) {
      out.exe_path = target;
      gchar* base = g_path_get_basename(target);
      out.exe_name = base;
      g_free(base);
      g_free(target);
    }
  }
  out.ok = !out.wm_class.empty() || !out.exe_name.empty();
#endif
  return out;
}

std::vector<WindowRect> GetVisibleWindows() {
  std::vector<WindowRect> out;
#ifdef GDK_WINDOWING_X11
  Display* dpy = XDisplay();
  if (dpy == nullptr) return out;

  unsigned long n = 0;
  unsigned char* data =
      ReadProperty(dpy, DefaultRootWindow(dpy), "_NET_CLIENT_LIST", XA_WINDOW, &n);
  if (data == nullptr) return out;
  Window* list = reinterpret_cast<Window*>(data);

  for (unsigned long i = 0; i < n; ++i) {
    Window win = list[i];
    if (!IsNormalWindowType(dpy, win)) continue;

    XWindowAttributes attrs;
    if (!XGetWindowAttributes(dpy, win, &attrs) || attrs.map_state != IsViewable) continue;

    int rx = 0, ry = 0;
    Window child = 0;
    XTranslateCoordinates(dpy, win, DefaultRootWindow(dpy), 0, 0, &rx, &ry, &child);

    WindowRect r;
    r.id = win;
    r.wm_class = WindowClass(dpy, win);
    r.title = WindowTitle(dpy, win);
    r.x = rx;
    r.y = ry;
    r.width = attrs.width;
    r.height = attrs.height;
    r.minimized = HasState(dpy, win, "_NET_WM_STATE_HIDDEN");
    if (r.title.empty() || r.width <= 0 || r.height <= 0) continue;
    out.push_back(r);
  }
  XFree(data);
#endif
  return out;
}

double GetIdleSeconds() {
  // Mutter exposes the session idle time over D-Bus on both X11 and Wayland.
  GVariant* reply = CallSync(G_BUS_TYPE_SESSION, "org.gnome.Mutter.IdleMonitor",
                             "/org/gnome/Mutter/IdleMonitor/Core",
                             "org.gnome.Mutter.IdleMonitor", "GetIdletime", nullptr);
  if (reply == nullptr) return 0.0;
  guint64 ms = 0;
  g_variant_get(reply, "(t)", &ms);
  g_variant_unref(reply);
  return static_cast<double>(ms) / 1000.0;
}

bool GetCursorPosition(double* x, double* y) {
  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr) return false;
  GdkSeat* seat = gdk_display_get_default_seat(display);
  if (seat == nullptr) return false;
  GdkDevice* pointer = gdk_seat_get_pointer(seat);
  if (pointer == nullptr) return false;
  gint px = 0, py = 0;
  gdk_device_get_position(pointer, nullptr, &px, &py);
  *x = px;
  *y = py;
  return true;
}

std::vector<DisplayRect> GetDisplays() {
  std::vector<DisplayRect> out;
  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr) return out;

  int count = gdk_display_get_n_monitors(display);
  for (int i = 0; i < count; ++i) {
    GdkMonitor* mon = gdk_display_get_monitor(display, i);
    if (mon == nullptr) continue;

    GdkRectangle geo, work;
    gdk_monitor_get_geometry(mon, &geo);
    gdk_monitor_get_workarea(mon, &work);

    DisplayRect d;
    const char* model = gdk_monitor_get_model(mon);
    d.id = (model != nullptr && model[0] != '\0') ? model : "Display_" + std::to_string(i);
    d.primary = gdk_monitor_is_primary(mon);
    d.x = geo.x;
    d.y = geo.y;
    d.width = geo.width;
    d.height = geo.height;
    d.work_x = work.x;
    d.work_y = work.y;
    d.work_width = work.width;
    d.work_height = work.height;
    d.scale = gdk_monitor_get_scale_factor(mon);
    int mhz = gdk_monitor_get_refresh_rate(mon);
    d.refresh_hz = mhz > 0 ? mhz / 1000.0 : 60.0;
    out.push_back(d);
  }

  // Some compositors report no primary; the first monitor is the primary then.
  if (!out.empty() &&
      std::none_of(out.begin(), out.end(), [](const DisplayRect& d) { return d.primary; })) {
    out.front().primary = true;
  }
  return out;
}

std::string GetAppearance() {
  GSettingsSchemaSource* source = g_settings_schema_source_get_default();
  if (source != nullptr) {
    GSettingsSchema* schema =
        g_settings_schema_source_lookup(source, "org.gnome.desktop.interface", TRUE);
    if (schema != nullptr) {
      bool dark = false;
      if (g_settings_schema_has_key(schema, "color-scheme")) {
        GSettings* settings = g_settings_new("org.gnome.desktop.interface");
        gchar* scheme = g_settings_get_string(settings, "color-scheme");
        dark = scheme != nullptr && std::strcmp(scheme, "prefer-dark") == 0;
        g_free(scheme);
        g_object_unref(settings);
      }
      g_settings_schema_unref(schema);
      if (dark) return "dark";
    }
  }
  gboolean prefer_dark = FALSE;
  gchar* theme = nullptr;
  g_object_get(gtk_settings_get_default(), "gtk-application-prefer-dark-theme", &prefer_dark,
               "gtk-theme-name", &theme, nullptr);
  bool dark = prefer_dark || (theme != nullptr && Contains(Lower(theme), "dark"));
  g_free(theme);
  return dark ? "dark" : "light";
}

bool IsDoNotDisturb() {
  GSettingsSchemaSource* source = g_settings_schema_source_get_default();
  if (source == nullptr) return false;
  GSettingsSchema* schema =
      g_settings_schema_source_lookup(source, "org.gnome.desktop.notifications", TRUE);
  if (schema == nullptr) return false;

  bool dnd = false;
  if (g_settings_schema_has_key(schema, "show-banners")) {
    GSettings* settings = g_settings_new("org.gnome.desktop.notifications");
    dnd = !g_settings_get_boolean(settings, "show-banners");
    g_object_unref(settings);
  }
  g_settings_schema_unref(schema);
  return dnd;
}

bool IsMeetingApp(const std::string& wm_class, const std::string& exe_name) {
  static const char* const kMeetingApps[] = {"zoom",  "teams", "teams-for-linux", "webex",
                                             "skype", "slack", "discord"};
  std::string cls = Lower(wm_class);
  std::string exe = Lower(exe_name);
  for (const char* app : kMeetingApps) {
    if (Contains(cls, app) || Contains(exe, app)) return true;
  }
  return false;
}

bool IsMicrophoneInUse() {
  // An ALSA capture substream reports RUNNING while any client (including
  // PipeWire / PulseAudio on behalf of an app) is recording from it.
  glob_t matches;
  std::memset(&matches, 0, sizeof(matches));
  bool running = false;
  if (glob("/proc/asound/card*/pcm*c/sub*/status", 0, nullptr, &matches) == 0) {
    for (size_t i = 0; i < matches.gl_pathc && !running; ++i) {
      std::string status = ReadFileToString(matches.gl_pathv[i]);
      running = status.find("state: RUNNING") != std::string::npos;
    }
  }
  globfree(&matches);
  return running;
}

bool IsCameraInUse() {
  // A video4linux node is "in use" when some process holds an fd to it.
  GDir* proc = g_dir_open("/proc", 0, nullptr);
  if (proc == nullptr) return false;

  const pid_t self = getpid();
  bool in_use = false;
  const gchar* entry;
  while (!in_use && (entry = g_dir_read_name(proc)) != nullptr) {
    char* end = nullptr;
    long pid = std::strtol(entry, &end, 10);
    if (end == entry || *end != '\0' || pid == self) continue;

    gchar* fd_dir_path = g_strdup_printf("/proc/%ld/fd", pid);
    GDir* fds = g_dir_open(fd_dir_path, 0, nullptr);
    if (fds != nullptr) {
      const gchar* fd;
      while (!in_use && (fd = g_dir_read_name(fds)) != nullptr) {
        gchar* link_path = g_build_filename(fd_dir_path, fd, nullptr);
        gchar* target = g_file_read_link(link_path, nullptr);
        if (target != nullptr && g_str_has_prefix(target, "/dev/video")) in_use = true;
        g_free(target);
        g_free(link_path);
      }
      g_dir_close(fds);
    }
    g_free(fd_dir_path);
  }
  g_dir_close(proc);
  return in_use;
}

namespace {

// GNOME: any idle-inhibiting client other than us means "something is playing".
bool GnomeIdleInhibited(bool* available) {
  GVariant* reply =
      CallSync(G_BUS_TYPE_SESSION, "org.gnome.SessionManager", "/org/gnome/SessionManager",
               "org.gnome.SessionManager", "GetInhibitors", nullptr);
  *available = reply != nullptr;
  if (reply == nullptr) return false;

  bool inhibited = false;
  GVariant* paths = g_variant_get_child_value(reply, 0);
  GVariantIter iter;
  g_variant_iter_init(&iter, paths);
  const gchar* object_path = nullptr;
  while (!inhibited && g_variant_iter_next(&iter, "&o", &object_path)) {
    GVariant* flags =
        CallSync(G_BUS_TYPE_SESSION, "org.gnome.SessionManager", object_path,
                 "org.gnome.SessionManager.Inhibitor", "GetFlags", nullptr);
    if (flags == nullptr) continue;
    guint32 f = 0;
    g_variant_get(flags, "(u)", &f);
    g_variant_unref(flags);
    if ((f & 8) == 0) continue;  // 8 = inhibit idle

    bool ours = false;
    for (const char* method : {"GetAppId", "GetReason"}) {
      GVariant* text = CallSync(G_BUS_TYPE_SESSION, "org.gnome.SessionManager", object_path,
                                "org.gnome.SessionManager.Inhibitor", method, nullptr);
      if (text == nullptr) continue;
      const gchar* s = nullptr;
      g_variant_get(text, "(&s)", &s);
      if (s != nullptr && Contains(Lower(s), "breakmate")) ours = true;
      g_variant_unref(text);
    }
    if (!ours) inhibited = true;
  }
  g_variant_unref(paths);
  g_variant_unref(reply);
  return inhibited;
}

// Fallback for non-GNOME sessions: any MPRIS player that is currently playing.
bool MprisPlaying() {
  GVariant* names = CallSync(G_BUS_TYPE_SESSION, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                             "org.freedesktop.DBus", "ListNames", nullptr);
  if (names == nullptr) return false;

  bool playing = false;
  GVariant* list = g_variant_get_child_value(names, 0);
  GVariantIter iter;
  g_variant_iter_init(&iter, list);
  const gchar* name = nullptr;
  while (!playing && g_variant_iter_next(&iter, "&s", &name)) {
    if (!g_str_has_prefix(name, "org.mpris.MediaPlayer2.")) continue;
    GVariant* status = CallSync(
        G_BUS_TYPE_SESSION, name, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties",
        "Get", g_variant_new("(ss)", "org.mpris.MediaPlayer2.Player", "PlaybackStatus"));
    if (status == nullptr) continue;
    GVariant* inner = nullptr;
    g_variant_get(status, "(v)", &inner);
    if (inner != nullptr) {
      const gchar* text = g_variant_get_string(inner, nullptr);
      playing = text != nullptr && std::strcmp(text, "Playing") == 0;
      g_variant_unref(inner);
    }
    g_variant_unref(status);
  }
  g_variant_unref(list);
  g_variant_unref(names);
  return playing;
}

}  // namespace

bool IsVideoPlaying() {
  bool gnome_available = false;
  bool inhibited = GnomeIdleInhibited(&gnome_available);
  if (gnome_available) return inhibited;
  return MprisPlaying();
}

std::vector<unsigned char> GetAppIconPng(const std::string& wm_class,
                                         const std::string& exe_name) {
  std::vector<unsigned char> png;
  GtkIconTheme* theme = gtk_icon_theme_get_default();
  if (theme == nullptr) return png;

  for (const std::string& name : {wm_class, Lower(exe_name)}) {
    if (name.empty()) continue;
    GdkPixbuf* pixbuf = gtk_icon_theme_load_icon(theme, name.c_str(), 64, GTK_ICON_LOOKUP_FORCE_SIZE,
                                                 nullptr);
    if (pixbuf == nullptr) continue;

    gchar* buffer = nullptr;
    gsize size = 0;
    if (gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &size, "png", nullptr, nullptr)) {
      png.assign(reinterpret_cast<unsigned char*>(buffer),
                 reinterpret_cast<unsigned char*>(buffer) + size);
      g_free(buffer);
    }
    g_object_unref(pixbuf);
    if (!png.empty()) break;
  }
  return png;
}

}  // namespace sys
}  // namespace bm
