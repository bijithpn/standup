#ifndef RUNNER_SECONDARY_WINDOWS_H_
#define RUNNER_SECONDARY_WINDOWS_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <map>
#include <memory>
#include <vector>

#include "bridge_util.h"

namespace bm {

// `com.breakmate/ipc`: lets each engine broadcast an event to every other one.
class IpcHub {
 public:
  static IpcHub& Get();

  // |key| identifies the engine so a sender is never echoed its own event.
  void Add(const void* key, FlBinaryMessenger* messenger);
  void Remove(const void* key);

 private:
  std::map<const void*, FlMethodChannel*> channels_;
};

// The break overlay, the companion and the picture-in-picture pet each live in
// their own GTK window with their own Flutter engine, selected by the
// `--breakmate-role=<role>` entrypoint argument (see lib/main.dart).
class SecondaryWindows {
 public:
  static SecondaryWindows& Get();

  // The main engine's `com.breakmate.desktop/bridge`, used to forward skip /
  // complete requests coming from the overlay. Not owned.
  void SetMainBridge(FlMethodChannel* bridge) { main_bridge_ = bridge; }

  void ShowOverlay(FlValue* args);
  void UpdateOverlay(FlValue* args);
  void HideOverlay();
  FlValue* LastOverlayArgs() const { return last_overlay_args_; }

  void ShowCompanion(FlValue* args);
  void UpdateCompanion(FlValue* params);
  void HideCompanion();

  void ShowPip(FlValue* args);
  void HidePip();

  // Monitors were added, removed or rearranged.
  void OnDisplaysChanged();

 private:
  struct Surface {
    GtkWidget* window = nullptr;
    FlView* view = nullptr;
    FlMethodChannel* bridge = nullptr;
    FlMethodChannel* data = nullptr;
    std::vector<FlMethodChannel*> channels;
    std::vector<std::unique_ptr<EventStream>> streams;
    bool want_visible = false;
    int monitor = 0;
    GdkRectangle geometry = {0, 0, 0, 0};
  };

  SecondaryWindows() = default;

  Surface* NewSurface(const char* role);
  void DestroySurface(Surface* surface);

  void PlaceOnMonitor(Surface* surface, int monitor_index, bool fullscreen);
  void AddOverlayChannels(Surface* surface);
  void AddCompanionChannels(Surface* surface, FlValue* initial_settings, const char* data_name);

  void ForwardToMain(const char* method);
  void ClearPool();

  static void OnFirstFrame(FlView* view, gpointer data);
  static gboolean OnDeleteEvent(GtkWidget*, GdkEvent*, gpointer) { return TRUE; }
  static gboolean OnOverlayKey(GtkWidget* widget, GdkEventKey* event, gpointer data);
  static gboolean OnPushOverlayData(gpointer data);
  static gboolean OnCompanionMouse(gpointer data);
  static gboolean OnCompanionMonitor(gpointer data);

  void SyncCompanionMouse();
  void FollowPointerMonitor();

  FlMethodChannel* main_bridge_ = nullptr;

  // Overlay: one surface per monitor. Hidden surfaces wait in |overlay_pool_|
  // so the next break does not pay for a cold engine start.
  std::vector<Surface*> overlays_;
  std::vector<Surface*> overlay_pool_;
  FlValue* last_overlay_args_ = nullptr;
  bool overlay_strict_ = false;
  guint overlay_push_source_ = 0;

  Surface* companion_ = nullptr;
  bool companion_follow_mouse_ = false;
  bool companion_click_through_ = false;
  guint companion_mouse_source_ = 0;
  guint companion_monitor_source_ = 0;

  Surface* pip_ = nullptr;
};

}  // namespace bm

#endif  // RUNNER_SECONDARY_WINDOWS_H_
