#ifndef RUNNER_BRIDGES_H_
#define RUNNER_BRIDGES_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <memory>

#include "bridge_util.h"

namespace bm {

// Registers every native channel the main window's engine talks to. Call once,
// after the FlView exists and before the first frame.
void RegisterMainBridges(FlView* view, GtkWindow* window);

// Answers the system queries every engine may ask over
// `com.breakmate.desktop/bridge` (idle time, cursor, windows, displays,
// constraint zone, appearance). Returns false when |call| is not one of them.
bool HandleSystemCall(FlMethodCall* call, bool is_main_engine);

// `com.breakmate/display_bridge` and `com.breakmate/display_events`. The caller
// owns both: unref |method| and drop |events| before the engine goes away.
struct DisplayChannels {
  FlMethodChannel* method = nullptr;
  std::unique_ptr<EventStream> events;
};
DisplayChannels NewDisplayChannels(FlBinaryMessenger* messenger, bool is_main_engine);

}  // namespace bm

#endif  // RUNNER_BRIDGES_H_
