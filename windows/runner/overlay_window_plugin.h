#ifndef RUNNER_OVERLAY_WINDOW_PLUGIN_H_
#define RUNNER_OVERLAY_WINDOW_PLUGIN_H_

#include <flutter/plugin_registry.h>

// Registers the overlay window plugin with the given plugin registry.
// Call this from FlutterWindow::OnCreate() after RegisterPlugins().
void RegisterOverlayWindowPlugin(flutter::PluginRegistry* registry);

#endif  // RUNNER_OVERLAY_WINDOW_PLUGIN_H_
