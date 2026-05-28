# BreakMate Roadmap

Last reviewed: 2026-05-28

## Project Snapshot

BreakMate is a desktop Flutter wellness app for macOS and Windows. The app uses a main dashboard engine, break overlays, native platform bridges, tray/menu-bar controls, analytics, smart pause detection, and a Flame-powered companion. The product direction is strong, but the next improvements should focus on startup time, frame stability, battery use, settings complexity, and confidence from tests.

Current scale:

- 112 Dart files under `lib/`.
- About 31 MB of bundled assets under `assets/`.
- Largest Dart files: `settings_page.dart` (~106 KB), `companion_interactive_template.dart` (~33 KB), `standalone_break_overlay.dart` (~30 KB), `timer_engine.dart` (~29 KB), `stats_service.dart` (~22 KB), `pet_asset_loader.dart` (~21 KB).
- Largest assets are six bundled lofi MP3 files (~3.2 MB to ~4.7 MB each), slideshow images, and full Inter font files.
- `flutter analyze` did not complete within 120 seconds during this review, so analyzer speed and project hygiene should be treated as a maintenance priority.

## Key Findings

1. The timer path rebuilds too broadly. `TimerEngine` calls `notifyListeners()` every second, and the app-level `ListenableBuilder` listens to the whole timer and overlay service. This can rebuild more UI than necessary.
2. Stats updates use `compute()` for every small increment. For one-minute usage ticks and single break counters, isolate startup/serialization may cost more than the calculation.
3. IPC is string/map based. Event names and payloads are duplicated in `main.dart`, `dependency_injection.dart`, and `IpcBridge`, which increases runtime failure risk.
4. The background polling isolate still proxies MethodChannel calls through the main isolate. That helps isolate app logic, but it does not fully remove native channel work from the UI isolate.
5. Asset strategy needs tightening. Bundled MP3s dominate asset size, font files are duplicated through the `Satoshi` alias, and pet/tray frame extraction writes generated images into the system temp directory.
6. Large UI files make changes slower and riskier. `settings_page.dart`, overlay templates, and standalone overlay code should be split into smaller feature widgets and controllers.
7. There are no visible dedicated test folders in the file list. Timer behavior, IPC event parsing, settings persistence, and analytics scoring need regression tests before deeper refactors.

## Priority 0: Measurement First

- [x] Add a repeatable performance profile script for desktop builds.
  - Measure cold start time, dashboard first frame, companion first visible frame, break overlay open latency, memory after 30 minutes, and CPU/GPU use while idle.
  - Save results in `docs/performance-baseline.md`.
- [x] Add Flutter DevTools performance snapshots for:
  - Idle dashboard.
  - Active countdown.
  - Break overlay.
  - Companion active and throttled.
- [x] Investigate why `flutter analyze` takes longer than 120 seconds.
  - Exclude generated/cache output such as `graphify-out/` if analyzer is scanning it.
  - Confirm `analysis_options.yaml` excludes build artifacts and generated folders.
  - Add a fast CI check that fails if analysis exceeds a reasonable timeout.
- [x] Add a local diagnostic command list in `docs/dev-checks.md`.
  - `flutter analyze`.
  - `flutter test`.
  - macOS debug run.
  - Windows debug run.
  - release build size check.
  - asset size report.
- [x] Add a frame-timing logger behind a debug flag.
  - Capture slow frames over 16 ms, 33 ms, and 100 ms.
  - Include current app state: dashboard, pre-break, break, companion, settings.
- [x] Add startup timing checkpoints.
  - Before `WidgetsFlutterBinding.ensureInitialized`.
  - After dependency injection.
  - After tray initialization.
  - After companion initialization.
  - First dashboard frame.
- [x] Add memory checkpoints for long sessions.
  - Startup.
  - After first companion show.
  - After switching pet themes five times.
  - After ten break overlays.
  - After one hour idle.

## Priority 1: Smoothness And Runtime Performance

- [x] Split timer state into smaller listenables/selectors.
  - Keep high-frequency countdown state separate from low-frequency settings/session state.
  - Use `Selector`, `ValueListenableBuilder`, or dedicated controllers so the full app shell does not rebuild every second.
- [x] Reduce tray updates to actual visible changes.
  - Only call `setTrayTitle` and `setTooltip` when the formatted value changed.
  - Avoid native tray calls every tick when menu bar display is not countdown-based.
- [x] Replace repeated `compute()` calls in `StatsService` with a debounced stats worker.
  - Batch small increments for 5-15 seconds.
  - Flush immediately when a break completes, app exits, or the day changes.
- [x] Move analytics calculations into pure functions with tests.
  - Keep isolate use only for heavy weekly/monthly trend generation.
- [x] Audit all periodic timers.
  - Timer tick: 1 second.
  - Standalone overlay local timer: 200 ms.
  - Smart detection: 5-10 seconds.
  - Companion behavior: 5-12 seconds depending on template.
  - Replace timer-driven UI where an `AnimationController`, target end timestamp, or lifecycle pause would be cheaper.
- [x] Pause overlay/template timers when the template is not visible.
  - Especially `companion_interactive_template.dart`, `soft_floating_widget_template.dart`, and activity widgets.
- [x] Add `RepaintBoundary` around high-frequency visual regions.
  - Countdown numerals.
  - Progress rings.
  - Flame companion canvas.
  - Break overlay animated backgrounds.
- [x] Cache decoded slideshow images and avoid loading full-size images when shown as background.
  - Generate smaller desktop-ready images where possible.
- [x] Add app lifecycle and window-focus throttling.
  - Lower companion FPS when dashboard is hidden, companion is click-through and idle, or the device is on battery.
  - Suspend non-essential timers while a strict break overlay is active.
- [x] Replace broad `Consumer<BreakController>` usage in overlay UI with narrower selectors.
  - Rebuild countdown text each second.
  - Keep static overlay layout from rebuilding each second.
- [x] Review `BreakMateApp` stack rendering.
  - Keep `MainLayout` alive only when needed.
  - Confirm `BreakOverlay` and `PreBreakWarningOverlay` do not do expensive work while hidden.
- [x] Add const constructors wherever possible in repeated widgets.
  - Settings sections.
  - Dashboard cards.
  - Overlay controls.
  - Analytics labels.
- [x] Avoid repeated `sl<T>()` service lookups in hot build paths.
  - Cache services in state objects where safe.
  - Pass dependencies down explicitly for frequently rebuilt widgets.
- [x] Review `StandaloneBreakOverlay` 200 ms timer.
  - Use target end time and a 1-second UI timer for text.
  - Keep smoother animation with `AnimationController`, not periodic `setState`.
- [x] Review `guided_breathing_widget.dart` and `eye_sync_game_widget.dart`.
  - Separate animation progress from session countdown.
  - Avoid full-widget `setState` on every tick.
- [x] Add template-level reduced-motion behavior.
  - Disable Ken Burns effects.
  - Disable floating background particles.
  - Disable companion bubble animation.
- [x] Ensure timers stop during app close/hide.
  - Break controller fade timers.
  - Tray animation timer.
  - Companion behavior timers.
  - Overlay template timers.
- [x] Add debounced settings save for sliders and rapid toggles.
  - Save immediately for critical settings.
  - Batch cosmetic changes like companion scale, template preview, and colors.

## Priority 2: Startup And Bundle Size

- [x] Build an asset budget report.
  - Track top 20 assets by size.
  - Fail CI if asset size grows unexpectedly.
- [x] Compress or externalize lofi audio.
  - Current bundled audio is the largest asset category.
  - Consider one bundled default track plus optional downloaded packs.
- [x] Optimize slideshow images.
  - Convert to WebP or lower-resolution PNG/JPEG variants.
  - Keep source-quality files outside the Flutter asset bundle.
- [x] Subset fonts.
  - Keep only glyphs and weights used in app UI.
  - Remove the `Satoshi` alias if it only points to Inter.
- [x] Lazy-load companion pet packs.
  - Load the selected pet at startup.
  - Load other pets only when the picker opens or the user previews them.
- [x] Persist generated tray icons in an app cache directory instead of system temp.
  - Use `path_provider`.
  - Include version/theme keys for safe invalidation.
- [x] Remove source assets from the runtime bundle if not used by the app.
  - Aseprite source files should stay outside `flutter.assets`.
  - Reference images should stay outside app bundle unless shown in UI.
- [x] Verify asset declarations are not duplicating folders and individual files unnecessarily.
  - `assets/music/` plus individual `assets/music/lofi_*.mp3` is redundant.
  - `assets/animations/pets/` plus specific pet manifest paths may be redundant.
- [x] Add lazy audio loading.
  - Do not initialize audio players until sound is enabled or a break starts.
  - Release audio resources when break music stops.
- [x] Add optional "no audio pack" build flavor.
  - Smaller installer for users who do not want lofi music.
- [x] Optimize app icon and tray icon assets.
  - Ensure each platform has correct sizes.
  - Avoid shipping oversized originals when only small variants are needed.
- [x] Cache pet manifest parsing.
  - Keep it loaded once.
  - Validate manifest shape at startup in debug mode only.
- [x] Consider deferred loading for heavy feature areas.
  - Wellness articles.
  - Analytics charts.
  - Companion picker.
  - Update/about section.

## Priority 3: Reliability And Architecture

- [x] Replace stringly typed IPC events with typed event models.
  - Define event names in one file.
  - Add `toJson` and `fromJson` validation for each payload.
  - Share parsing between main, overlay, and companion isolates.
- [x] Add IPC failure handling.
  - Track last successful event per channel.
  - Add retries for important events like break start/end.
  - Add debug logs only behind a verbose flag to avoid log noise.
- [x] Add tests for core behavior.
  - Timer start/pause/resume/reset.
  - Pre-break warning transition.
  - Long break scheduling.
  - Strict mode skip prevention.
  - Stats scoring and streak behavior.
  - Settings load/save defaults.
  - IPC payload parsing.
- [x] Fix streak logic so a day is counted once.
  - Current logic can increment current streak repeatedly after the daily threshold is reached unless guarded by a per-day flag.
- [x] Add a storage migration layer.
  - Version settings and stats payloads.
  - Migrate old keys such as `companion_cat_theme` to pet-neutral names.
- [x] Add graceful degradation for native bridge failures.
  - Windows currently uses a channel named `com.breakmate.macos/bridge` in `windows_bridge.dart`; confirm this is intentional or rename to a neutral channel.
  - Surface missing permissions and unsupported APIs in settings.
- [x] Review disposal paths.
  - Ensure services started in dependency injection are stopped on app quit.
  - Close stream subscriptions from meeting/focus/native services.
- [x] Add a central app shutdown coordinator.
  - Stop timers.
  - Flush stats.
  - Save timer state.
  - Stop background polling.
  - Hide overlays.
  - Dispose tray resources.
- [x] Make timer state transitions explicit.
  - Idle to running.
  - Running to pre-break.
  - Pre-break to break active.
  - Break active to completion.
  - Break active to skipped.
  - Running to paused.
  - Paused to running.
  - Any state to reset.
- [x] Make timer persistence resilient.
  - Store target end timestamps.
  - Recover after crash.
  - Recover after system sleep.
  - Avoid negative countdowns after long suspension.
- [x] Add permission/status models for native features.
  - Meeting detection available/unavailable.
  - Focus mode available/unavailable.
  - Notifications allowed/denied.
  - Launch at startup enabled/failed.
- [x] Unify native channel names.
  - Avoid macOS-named channels in Windows bridge code unless the native side requires it.
  - Document every channel in `docs/native-channels.md`.
- [x] Add platform capability checks before invoking native methods.
  - Prevent unsupported method spam in logs.
  - Show user-facing fallback only when action is needed.
- [x] Add a typed settings repository API.
  - Replace raw string keys scattered across the app with constants.
  - Group settings by domain.
  - Add defaults in one place.
- [x] Add storage integrity checks.
  - Detect corrupt JSON for exercises and weekly stats.
  - Restore defaults safely.
  - Keep a backup of last valid stats payload.
- [x] Add Sentry hygiene.
  - Remove or externalize DSN if needed.
  - Tag app version, platform, engine type, and feature area.
  - Avoid sending private active app names unless explicitly allowed.

## Priority 4: Code Organization

- [x] Split `settings_page.dart` into route-level sections.
  - [x] General.
  - [x] Breaks.
  - [x] Focus and detection.
  - [x] Companion.
  - [x] Analytics.
  - [x] Updates/about.
- [ ] Split break overlay templates into smaller widgets.
  - Separate stateful behavior timers from pure UI components.
  - Move copy/text/activity data into models.
- [ ] Extract `TimerEngine` orchestration from persistence and side effects.
  - Keep timer state transitions pure.
  - Move tray, notification, stats, and IPC reactions into listeners or coordinators.
- [x] Create a native bridge facade per platform with the same method names.
  - Remove platform-channel strings from feature widgets.
- [x] Add a `docs/architecture.md` with current engine/isolate responsibilities.
  - Main dashboard.
  - Break overlay.
  - Companion.
  - Native bridges.
  - Background polling.
- [x] Create `lib/features/settings/presentation/sections/`.
  - [x] Move each settings section into its own file.
  - [x] Keep `settings_page.dart` as layout and routing only.
- [x] Create `lib/features/break_overlay/domain/`.
  - Template model.
  - Activity model.
  - Break display state.
- [x] Create `lib/features/break_overlay/application/`.
  - Template selection controller.
  - Activity session controller.
  - Overlay animation coordinator.
- [x] Move stats isolate functions out of `stats_service.dart`.
  - `stats_calculator.dart`.
  - `stats_repository.dart`.
  - `stats_worker.dart` if batching is implemented.
- [ ] Move pet tray icon generation out of `pet_asset_loader.dart`.
  - Keep image loading separate from generated tray icon cache.
- [ ] Add barrel files only where they reduce import noise.
  - Avoid broad barrels that hide dependencies in core services.
- [ ] Standardize naming.
  - Use companion/pet consistently instead of mixing cat/pet keys.
  - Use break template IDs consistently across settings and UI.
- [x] Document ownership boundaries.
  - `core` has platform/services/utilities.
  - `features` own business behavior.
  - `shared` owns visual primitives.

## Priority 5: UX Improvements

- [ ] Add an onboarding flow.
  - Choose break profile.
  - Choose strictness.
  - Enable/disable smart meeting detection.
  - Pick companion or run without companion.
  - Explain permissions only when needed.
- [ ] Add a "Today" dashboard focused on action.
  - Next break.
  - Current focus session.
  - Completed vs skipped breaks.
  - One recommended adjustment.
- [ ] Add smarter break recommendations.
  - If skips are high, suggest shorter breaks or longer focus intervals.
  - If work sessions are long, suggest posture and eye-rest templates.
  - If meetings are frequent, suggest meeting-aware mode.
- [ ] Add quiet mode presets.
  - Presenting.
  - Meeting-heavy day.
  - Deep work.
  - Low battery.
- [ ] Add snooze choices with clear tradeoffs.
  - 5 minutes.
  - 15 minutes.
  - Until meeting ends.
  - Until current app exits.
- [ ] Improve companion controls.
  - Per-pet preview before applying.
  - Companion energy mode.
  - Click-through toggle in tray menu.
  - "Do not distract me" state.
- [ ] Improve break overlay accessibility.
  - Reduced motion.
  - High contrast mode.
  - Keyboard shortcuts for skip/postpone when strict mode is off.
  - Screen-reader labels for controls.
- [ ] Add a recovery flow after system sleep/wake.
  - Ask whether the time away counted as a break.
  - Resume, reset, or start a break based on user choice.
- [ ] Add first-run permission education.
  - Explain why notifications are useful.
  - Explain meeting detection privacy.
  - Explain companion click-through behavior.
- [ ] Add a compact tray popover redesign.
  - Current state.
  - Next break.
  - Start/pause/reset.
  - Quick snooze.
  - Toggle companion.
- [ ] Add better empty states.
  - No analytics yet.
  - No completed breaks today.
  - Smart detection unavailable.
  - Companion disabled.
- [ ] Add user-editable break profiles.
  - Health default.
  - Pomodoro.
  - Deep work.
  - Eye care.
  - Custom.
- [ ] Add break intensity levels.
  - Gentle reminder.
  - Standard overlay.
  - Strict full-screen.
  - Lock-like strict mode.
- [ ] Add a "why now?" explanation on break screens.
  - Long focus session.
  - Eye-rest interval reached.
  - Posture reminder.
  - End of day.
- [ ] Add better skip/postpone feedback.
  - Track reason optionally.
  - Suggest interval adjustment after repeated skips.
  - Avoid guilt-based language.
- [ ] Add companion mood transparency.
  - Show why companion is sleeping, alert, quiet, or playful.
  - Keep this available in settings or popover, not always on screen.
- [ ] Add keyboard and accessibility polish.
  - Focus order.
  - Escape behavior when strict mode is off.
  - Large text support.
  - Color contrast audit.
- [ ] Add localization readiness.
  - Move user-facing strings into localization files.
  - Avoid hard-coded copy inside deep widgets.

## Priority 6: Better Features

- [ ] Contextual Wellness Engine.
  - Use current app category, session length, skip history, and time of day.
  - Suggest wrist, eye, posture, breathing, hydration, or walk breaks.
- [ ] Break template marketplace/packs.
  - Keep core templates small.
  - Let users install optional visual/audio packs.
- [ ] Personal goals.
  - Daily focus target.
  - Daily break target.
  - Max continuous sitting target.
  - Weekly consistency target.
- [ ] Calendar-aware break planning.
  - Avoid starting breaks in scheduled meetings.
  - Suggest breaks between meetings.
- [ ] Local-only privacy report.
  - Show what is detected, what is stored, and what never leaves the machine.
- [ ] Companion progression without pressure.
  - Unlock accessories or animations through consistent healthy behavior.
  - Avoid streak mechanics that punish users for taking time off.
- [ ] Team mode as optional future work.
  - Shared break rooms.
  - Anonymous wellness trends.
  - No individual surveillance metrics.
- [ ] Mobile companion as optional future work.
  - Remote break reminder.
  - Away-from-desk confirmation.
  - Hydration/posture nudges.
- [ ] App-specific break behavior.
  - Writing apps: wrist and neck breaks.
  - Browser/video apps: eye-rest breaks.
  - IDE/design apps: posture and shoulder breaks.
  - Meeting apps: after-meeting reset.
- [ ] Smart end-of-day wind-down.
  - Gentle clock-out warning.
  - Final break suggestion.
  - Summary of the day.
- [ ] Personal wellness library.
  - Favorite exercises.
  - Hide exercises the user dislikes.
  - Rotate exercises to avoid repetition.
- [ ] Break activity progression.
  - Guided breathing.
  - Eye focus.
  - Neck mobility.
  - Shoulder mobility.
  - Wrist mobility.
  - Hydration walk.
- [ ] Companion interactions that support the goal.
  - Companion points to break button near break time.
  - Companion sleeps during meetings.
  - Companion celebrates completed breaks.
  - Companion becomes quieter after repeated dismissals.
- [ ] Optional integrations.
  - Calendar.
  - Slack status.
  - Teams status.
  - Apple Shortcuts.
  - Windows Focus Sessions.
- [ ] Privacy-first analytics export.
  - CSV export.
  - JSON backup.
  - Local-only import/restore.
- [ ] Theme and visual customization.
  - Break overlay themes.
  - Companion scale and position presets.
  - Reduced blur mode for low-end devices.
  - High contrast theme.

## File-Specific Backlog

### `lib/core/services/timer_engine.dart`

- [ ] Split high-frequency countdown state from session lifecycle state.
- [ ] Add pure transition tests before refactor.
- [ ] Stop calling `saveState()` too often during rapid transitions.
- [ ] Debounce tray updates.
- [ ] Replace repeated `notifyListeners()` calls with narrower event streams.
- [ ] Add explicit handling for clock changes and timezone changes.
- [ ] Guard against multiple `startTimers()` calls creating duplicated activity monitor callbacks.

### `lib/features/analytics/stats_service.dart`

- [ ] Fix daily streak increment so one day increments once.
- [ ] Batch stat writes.
- [ ] Move calculation functions to a pure calculator file.
- [ ] Add tests for completion rate, productivity score, wellness score, weekly rollover, and corrupt JSON.
- [ ] Add monthly and yearly aggregation without recalculating everything on every update.

### `lib/features/settings/settings_page.dart`

- [ ] Split into smaller section files.
- [ ] Move settings mutation logic into controller methods.
- [ ] Debounce slider saves.
- [ ] Add search for settings.
- [ ] Add reset-to-default per section.
- [ ] Add inline permission status for native integrations.

### `lib/features/break_system/presentation/standalone_break_overlay.dart`

- [ ] Reduce 200 ms timer-driven rebuilds.
- [ ] Split large widget into template, controls, countdown, and native data adapter.
- [ ] Add strict mode interaction tests.
- [ ] Add reduced-motion support.
- [ ] Add fallback if native overlay data is delayed.

### `lib/features/break_system/presentation/break_overlay.dart`

- [ ] Ensure hidden overlays do not animate or load assets.
- [ ] Narrow provider listening.
- [ ] Move template selection to a registry.
- [ ] Add template performance budget.

### `lib/features/break_overlay/presentation/templates/companion_interactive_template.dart`

- [ ] Reduce nested state and repeated timers.
- [ ] Extract speech bubble controller.
- [ ] Extract pet interaction controls.
- [ ] Add reduced-motion and low-power behavior.
- [ ] Ensure all timers stop when break ends.

### `lib/features/companion/flame/companion_game.dart`

- [ ] Verify throttling actually reduces render cost, not just update cost.
- [ ] Add pause/resume API for hidden companion.
- [ ] Add memory test for repeated theme changes.
- [ ] Add debug overlay for FPS, active theme, and throttled state.
- [ ] Avoid loading every animation state if only a few are needed for tray preview.

### `lib/features/companion/flame/companion_component.dart`

- [ ] Pool procedural fire particles instead of allocating constantly.
- [ ] Disable particles in low-power/reduced-motion mode.
- [ ] Move render badge text painter creation out of every frame.
- [ ] Cache paint objects where possible.
- [ ] Keep movement animation transitions deterministic and tested.

### `lib/features/companion/assets/pet_asset_loader.dart`

- [ ] Separate loading, decoding, cropping, and tray icon generation.
- [ ] Move generated files from system temp to app cache directory.
- [ ] Add cache size limits and clear-cache controls.
- [ ] Avoid scanning image alpha repeatedly when cached metadata exists.
- [ ] Validate asset paths at startup in debug mode.

### `lib/core/services/background_polling_service.dart`

- [ ] Add platform guards.
- [ ] Back off polling when app is paused or smart detection disabled.
- [ ] Avoid proxying unsupported native calls repeatedly.
- [ ] Add structured error reporting for unavailable native methods.
- [ ] Ensure `stop()` completes cleanly and no messages arrive after close.

### `lib/core/ipc/ipc_bridge.dart`

- [ ] Add typed events.
- [ ] Add payload validation.
- [ ] Add event versioning.
- [ ] Add optional acknowledgements for critical events.
- [ ] Reduce default logging in release mode.

### `lib/app/dependency_injection.dart`

- [ ] Move service startup order into documented phases.
- [ ] Avoid starting optional services before settings determine they are enabled.
- [ ] Add shutdown/dispose support.
- [ ] Add integration tests for service graph creation.

## Platform-Specific Backlog

### macOS

- [ ] Verify Sparkle update flow end to end.
- [ ] Verify notification permission behavior.
- [ ] Verify Focus/DND detection permissions and fallback.
- [ ] Verify companion panel behavior across Spaces and fullscreen apps.
- [ ] Verify strict overlay window level.
- [ ] Verify app resumes correctly after sleep/wake.
- [ ] Verify launch-at-startup registration.
- [ ] Verify signed/notarized build pipeline.

### Windows

- [ ] Verify overlay topmost behavior on multi-monitor setups.
- [ ] Verify tray icon animation performance.
- [ ] Verify Windows bridge channel naming.
- [ ] Verify focus/meeting detection parity or document missing capability.
- [ ] Verify DPI scaling for companion and overlay.
- [ ] Verify installer/startup behavior.
- [ ] Verify window close/minimize behavior.

## Testing Backlog

- [ ] Unit tests for timer state transitions.
- [ ] Unit tests for settings defaults and save/load.
- [ ] Unit tests for stats scoring.
- [ ] Unit tests for IPC event parsing.
- [ ] Unit tests for pet state machine transitions.
- [ ] Widget tests for countdown UI.
- [ ] Widget tests for settings sections after split.
- [ ] Widget tests for break overlay controls.
- [ ] Golden tests for critical overlay templates.
- [ ] Integration test for start -> pre-break -> break -> finish.
- [ ] Integration test for skip and postpone when strict mode is off.
- [ ] Integration test proving strict mode blocks skip paths.
- [ ] Integration test for meeting detection pause/resume using fake bridge.
- [ ] Smoke test for companion theme switching.
- [ ] Smoke test for app startup with corrupt storage values.

## Build And Release Backlog

- [ ] Add CI workflow for analyze and tests.
- [ ] Add CI workflow for macOS build if runner is available.
- [ ] Add CI workflow for Windows build if runner is available.
- [ ] Add version bump checklist.
- [ ] Add release notes template.
- [ ] Add asset budget report to CI output.
- [ ] Add installer size tracking.
- [ ] Add crash-free startup smoke test.
- [ ] Add signing/notarization documentation.
- [ ] Add rollback plan for broken auto-update releases.

## Security And Privacy Backlog

- [ ] Document all local data stored by the app.
- [ ] Document all native permissions requested.
- [ ] Add "delete my local data" action.
- [ ] Add export/backup action.
- [ ] Make Sentry opt-in or clearly disclosed if release telemetry is used.
- [ ] Avoid logging active app names by default.
- [ ] Avoid logging user settings values that could reveal work habits.
- [ ] Keep team features anonymous and optional if implemented.

## Suggested Execution Order

1. Fix analyzer timeout and add basic test/analysis CI.
2. Add timer, stats, settings, and IPC tests.
3. Refactor timer rebuild/listener behavior.
4. Debounce stats writes and tray updates.
5. Reduce overlay/template timers and hidden animations.
6. Optimize assets and audio bundle size.
7. Split `settings_page.dart` and large overlay files.
8. Type IPC events and native bridge capabilities.
9. Add onboarding, today dashboard, and smarter recommendations.
10. Add optional advanced features like calendar, team, and mobile sync.

## Validation Checklist Before Release

- [ ] `flutter analyze` completes successfully within the target time.
- [ ] Unit tests cover timer, settings, stats, and IPC parsing.
- [ ] Desktop smoke test on macOS and Windows.
- [ ] Cold start measured before and after optimization.
- [ ] Companion idle CPU/GPU measured on AC and battery.
- [ ] Break overlay opens without dropped frames.
- [ ] Strict mode cannot be skipped through window blur/close paths.
- [ ] App works with meeting detection unavailable or denied.
- [ ] Asset bundle size is documented.
- [ ] Existing generated file changes are reviewed before commit.

## Completed Or Existing Capabilities

- [x] Main break timer and break overlay flow.
- [x] Pre-break warning overlay.
- [x] Strict mode concept.
- [x] Settings persistence.
- [x] Tray/menu-bar controls.
- [x] Analytics model and weekly stats display.
- [x] Companion pet system with Flame animations.
- [x] Companion behavior/state services.
- [x] Smart detection hooks for meetings/focus mode.
- [x] Native macOS and Windows bridge files.
- [x] Update UI section and Sparkle-related macOS release scripts.
