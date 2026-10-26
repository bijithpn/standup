#ifndef RUNNER_ENHANCEMENTS_H_
#define RUNNER_ENHANCEMENTS_H_

#include <flutter_linux/flutter_linux.h>

namespace bm {

// `com.breakmate/native_enhancements`: cursor countdown pill, flash reminder
// and display-sleep prevention.
void RegisterEnhancements(FlBinaryMessenger* messenger);

// `com.breakmate/smart_detection_events`: microphone, camera, playing video and
// Do Not Disturb, pushed on change.
void RegisterSmartDetection(FlBinaryMessenger* messenger);

}  // namespace bm

#endif  // RUNNER_ENHANCEMENTS_H_
