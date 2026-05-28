# BreakMate Performance Baseline

Use this file to record performance measurements before and after optimization work.
Run measurements on a release build unless noted otherwise.

---

## How to Measure

### Cold Start Time
```bash
# macOS — measure time from launch to first frame
flutter run -d macos --profile --trace-startup
# Look for "time_to_first_frame" in the output JSON
```

### Frame Timing
Set `kEnableFrameTimingLog = true` in `lib/core/utils/frame_timing_logger.dart`,
run in debug mode, and watch the console for slow-frame warnings.

### Memory
Open Flutter DevTools → Memory tab while the app is running.
Take a heap snapshot at each checkpoint listed below.

### CPU / GPU
Open Flutter DevTools → Performance tab.
Record a 30-second trace for each scenario.

---

## Baseline Measurements

> Fill in after running the profiling steps above.
> Date: ___________
> Build: ___________  (git commit hash)
> Platform: macOS / Windows

### Cold Start

| Checkpoint | Time (ms) |
|---|---|
| WidgetsFlutterBinding.ensureInitialized | |
| initDependencies complete | |
| windowManager.ensureInitialized | |
| First dashboard frame rendered | |

### Frame Rate (60 fps target = 16.7 ms/frame)

| Scenario | Avg frame (ms) | Slow frames (>16ms) | Jank frames (>33ms) |
|---|---|---|---|
| Idle dashboard | | | |
| Active countdown (last 20 s) | | | |
| Break overlay open | | | |
| Companion active | | | |
| Companion throttled | | | |
| Settings page scroll | | | |

### Memory

| Checkpoint | Heap (MB) | RSS (MB) |
|---|---|---|
| Startup | | |
| After first companion show | | |
| After switching pet themes ×5 | | |
| After 10 break overlays | | |
| After 1 hour idle | | |

### CPU / GPU (Idle)

| Scenario | CPU % | GPU % |
|---|---|---|
| Dashboard hidden, companion idle | | |
| Dashboard visible, no activity | | |
| Companion click-through, throttled | | |

### Bundle Size

| Platform | App size (MB) | Notes |
|---|---|---|
| macOS .app | | |
| Windows runner/ | | |

### Asset Budget

| Category | Size (MB) |
|---|---|
| Music (lofi MP3s) | ~25 |
| Slideshow images | |
| Pet animations | |
| Fonts | |
| Other | |
| **Total** | |

---

## Optimization History

| Date | Change | Before | After | Delta |
|---|---|---|---|---|
| | | | | |
