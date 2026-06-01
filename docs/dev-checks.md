# BreakMate Dev Checks

Local diagnostic commands to run before committing or investigating issues.

## Static Analysis

```bash
flutter analyze
```

Expected: no errors, no warnings. Should complete within 30 seconds.
If it times out, verify `analysis_options.yaml` excludes are in effect (graphify-out/, build/, .dart_tool/).

## Tests

```bash
flutter test
```

Run all unit and widget tests. All should pass before merging.

For task work where tests are explicitly out of scope, do not run this command.
Record that tests were intentionally skipped in the final note or release checklist.

## Format And Analyzer Timing

```bash
time dart format --set-exit-if-changed lib tool
time flutter analyze
```

Expected: no formatting changes and no analyzer errors. `flutter analyze` should
complete within 30 seconds on a warm machine. If it exceeds 60 seconds, verify
`analysis_options.yaml` excludes are in effect for `graphify-out/`, `build/`,
`.dart_tool/`, and generated files.

## macOS Debug Run

```bash
flutter run -d macos
```

Watch for startup errors in the console. Check that:
- Tray icon appears
- Dashboard window opens (or hides to tray correctly)
- Companion window launches if enabled

## Windows Debug Run

```bash
flutter run -d windows
```

Watch for startup errors. Check that:
- Tray icon appears in system tray
- Dashboard window opens
- Overlay window can be triggered

## Release Build Size Check

### macOS
```bash
flutter build macos --release
du -sh build/macos/Build/Products/Release/BreakMate.app
```

### Windows
```bash
flutter build windows --release
du -sh build/windows/x64/runner/Release/
```

Target: keep the app bundle under 150 MB. Alert if it grows unexpectedly.

## Asset Size Report

```bash
# Repeatable budget report
dart run tool/asset_budget.dart --warn-only

# List top assets by size (macOS/Linux)
find assets/ -type f | xargs ls -lS | head -30

# Windows (PowerShell)
Get-ChildItem -Recurse assets/ | Sort-Object Length -Descending | Select-Object -First 30 | Format-Table Name, Length
```

Key budget:
- Total asset tree: target under 20 MB
- Music files: one bundled default track, currently ~4 MB
- Fonts: currently ~1.6 MB total; subset before release if installer size grows
- Tray/source images: keep oversized source/reference images out of Flutter asset declarations
- Pet animations: load only the selected pet at startup where possible

## Manual Smoke Checks

Use these checks when automated integration tests are intentionally skipped.

### macOS

- Launch the app from a debug or release build.
- Confirm the tray/menu-bar icon appears.
- Open the dashboard from the tray/menu-bar popover.
- Start, pause, resume, reset, and snooze the timer.
- Trigger Break Now and confirm the overlay opens.
- Confirm strict or locked mode hides skip/postpone actions as configured.
- Toggle companion on/off, click-through, low-distraction mode, and pet theme.
- Enable calendar support and confirm the dashboard shows meeting conflicts only when actionable.

### Windows

- Launch the app from a debug or release build.
- Confirm the system tray icon appears.
- Open the dashboard from the tray popover.
- Start, pause, resume, reset, and snooze the timer.
- Trigger Break Now and confirm the topmost overlay opens on the expected display.
- Confirm strict or locked mode cannot be bypassed through the overlay controls.
- Toggle companion on/off, click-through, low-distraction mode, and pet theme.
- Confirm DPI scaling keeps the tray popover, overlay, and companion readable.

## Flutter DevTools Performance Snapshots

Launch DevTools for performance profiling:

```bash
flutter run -d macos --profile
# Then open the DevTools URL printed in the console
```

**Required snapshots to capture (save to docs/performance-baseline.md):**

1. **Idle dashboard** — CPU/GPU/memory baseline
   - Hide dashboard to tray, let sit for 30s, take snapshot
2. **Active countdown** — Last 20 seconds before break
   - Start timer, wait until <20s remaining, take snapshot  
3. **Break overlay** — Full-screen break active
   - Trigger break, wait 5s for animations to settle, take snapshot
4. **Companion active** — Pet animations running
   - Show companion, ensure it's animating, take snapshot
5. **Companion throttled** — Low-power mode
   - Enable companion throttling in settings, take snapshot

For each snapshot, record:
- CPU usage %
- GPU usage % 
- Memory heap size (MB)
- Frame rate (fps)

## Frame Timing (Debug Flag)

Enable the frame-timing logger by setting `kEnableFrameTimingLog = true` in
`lib/core/utils/frame_timing_logger.dart`, then run in debug mode and watch
the console for slow-frame warnings (>16 ms, >33 ms, >100 ms).

## Memory Checkpoints (Debug Flag)

Enable memory logging by setting `kEnableMemoryCheckpoints = true` in
`lib/core/utils/memory_checkpoints.dart`. This logs RSS memory usage at:

- Startup
- After first companion show  
- After switching pet themes 5x
- After ten break overlays
- After one hour idle

Manual checkpoint calls can be added at test points:
```dart
MemoryCheckpoints.instance.logCheckpoint('test_point_name');
```

## Analyzer Timeout Check (CI)

```bash
# Fail if analyze takes longer than 60 seconds
timeout 60 flutter analyze || echo "ANALYZER TIMEOUT — check analysis_options.yaml excludes"
```
