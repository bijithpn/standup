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

Date: 2026-05-31
Build: 1.2.0+30
Platform: macOS / Windows desktop target
Source: local static project audit plus pending profile-build runtime captures.

Runtime profile captures still need to be recorded from a profile or release build on the release machine. This baseline now records the static startup and bundle indicators that can be measured without launching the app.

### Cold Start

| Checkpoint | Time (ms) |
|---|---|
| WidgetsFlutterBinding.ensureInitialized | Pending profile run |
| initDependencies complete | Pending profile run |
| windowManager.ensureInitialized | Pending profile run |
| First dashboard frame rendered | Pending profile run |

### Frame Rate (60 fps target = 16.7 ms/frame)

| Scenario | Avg frame (ms) | Slow frames (>16ms) | Jank frames (>33ms) |
|---|---|---|---|
| Idle dashboard | Pending profile run | Pending profile run | Pending profile run |
| Active countdown (last 20 s) | Pending profile run | Pending profile run | Pending profile run |
| Break overlay open | Pending profile run | Pending profile run | Pending profile run |
| Companion active | Pending profile run | Pending profile run | Pending profile run |
| Companion throttled | Pending profile run | Pending profile run | Pending profile run |
| Settings page scroll | Pending profile run | Pending profile run | Pending profile run |

### Memory

| Checkpoint | Heap (MB) | RSS (MB) |
|---|---|---|
| Startup | Pending profile run | Pending profile run |
| After first companion show | Pending profile run | Pending profile run |
| After switching pet themes x5 | Pending profile run | Pending profile run |
| After 10 break overlays | Pending profile run | Pending profile run |
| After 1 hour idle | Pending profile run | Pending profile run |

### CPU / GPU (Idle)

| Scenario | CPU % | GPU % |
|---|---|---|
| Dashboard hidden, companion idle | Pending profile run | Pending profile run |
| Dashboard visible, no activity | Pending profile run | Pending profile run |
| Companion click-through, throttled | Pending profile run | Pending profile run |

### Bundle Size

| Platform | App size (MB) | Notes |
|---|---|---|
| macOS .app | Pending release build | Run `flutter build macos --release` |
| Windows runner/ | Pending release build | Run `flutter build windows --release` |

### Asset Budget

| Category | Size (MB) |
|---|---|
| Slideshow images | ~13 |
| Music (lofi MP3s) | ~4.0 |
| Fonts | ~1.6 |
| Icons | ~0.6 |
| Pet animations | ~0.5 |
| Backgrounds | ~0.2 |
| Other | ~1.1 |
| **Total** | ~21 |

### Static Startup Risk Markers

| Marker | Baseline | Notes |
|---|---|---|
| Dart files under `lib/` | 160 | Runtime and UX hubs remain broad. |
| Largest hand-written feature files | `breaks_settings_section.dart`, `dashboard_page.dart`, `standalone_break_overlay.dart`, `companion_interactive_template.dart` | Good first targets for smaller widgets/controllers. |
| Optional services started near startup | Smart detection, stats, tray, companion controller, pet discovery, tray icon cache | Gate by settings or first visible use where possible. |
| Largest asset group | `assets/slideshow/` at ~13 MB | First bundle-size target. |

---

## Optimization History

| Date | Change | Before | After | Delta |
|---|---|---|---|---|
| 2026-05-31 | Static baseline recorded | Blank baseline | Asset/runtime-risk baseline documented | Enables targeted profile capture |
