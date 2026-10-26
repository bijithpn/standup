#ifndef RUNNER_NATIVE_ENHANCEMENTS_BRIDGE_H_
#define RUNNER_NATIVE_ENHANCEMENTS_BRIDGE_H_

#include <flutter/flutter_engine.h>

// Registers `com.breakmate/native_enhancements`: cursor countdown pill, flash
// reminder and display-sleep prevention. Mirrors the macOS channel of the same
// name. Must be called on the UI thread of the main window.
void RegisterNativeEnhancementsBridge(flutter::FlutterEngine* engine);

// Registers the `com.breakmate/smart_detection_events` stream: microphone,
// camera, fullscreen/presentation and Focus Assist state.
void RegisterSmartDetectionBridge(flutter::FlutterEngine* engine);

#endif  // RUNNER_NATIVE_ENHANCEMENTS_BRIDGE_H_
