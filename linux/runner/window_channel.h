#ifndef RUNNER_WINDOW_CHANNEL_H_
#define RUNNER_WINDOW_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

namespace bm {

// `com.breakmate/window`: lets Dart move, size, restyle and drag the toplevel
// that hosts this engine. |window| may be destroyed at any time; the channel
// then answers with nulls instead of touching a dangling pointer. The caller
// owns the returned channel reference.
FlMethodChannel* NewWindowChannel(FlBinaryMessenger* messenger, GtkWidget* window);

}  // namespace bm

#endif  // RUNNER_WINDOW_CHANNEL_H_
