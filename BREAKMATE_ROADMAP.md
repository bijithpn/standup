# BreakMate Roadmap

Last reviewed: 2026-05-29

## Project Snapshot

BreakMate is a desktop Flutter wellness app for macOS and Windows. The app uses a main dashboard engine, break overlays, native platform bridges, tray/menu-bar controls, analytics, smart pause detection, and a Flame-powered companion. The product direction is strong, but the next improvements should focus on startup time, frame stability, battery use, settings complexity, and confidence from tests.

Current scale:

- 143 Dart files under `lib/`.
- About 7.4 MB of files under `assets/`.
- Largest Dart files: `breaks_settings_section.dart` (~42.5 KB), `companion_interactive_template.dart` (~33 KB), `standalone_break_overlay.dart` (~29.6 KB), `timer_engine.dart` (~29.2 KB), `pet_asset_loader.dart` (~21 KB), `companion_settings_section.dart` (~19.9 KB), `pet_theme.dart` (~18.8 KB), and `classic_slideshow_template.dart` (~18.4 KB).
- Largest assets are `assets/music/lofi_1.mp3` (~4.0 MB), full Inter font files (~400 KB each), `assets/icons/tray_icon.png` (~366 KB), source reference image `Frame_indexes.png` (~190 KB), and companion tray PNGs.
- `flutter analyze`, `flutter test`, `dart analyze`, and `dart format` did not complete within 120-180 seconds during the 2026-05-29 review, so Dart/Flutter tool startup or analyzer project hygiene remains an active blocker.

## 2026-05-29 Status Correction

Verified as implemented or materially improved:

- Settings page has been split into route-level section files.
- Asset bundle size has been reduced from the previous review; only one lofi track is declared in `pubspec.yaml`.
- Stats calculations moved into `stats_calculator.dart`, with targeted tests for scoring and one-streak-per-day behavior.
- IPC has typed event classes, payload parsing/validation, version metadata, retrying dispatch, and last-success tracking.
- Companion theme persistence now writes to `companion_pet_theme` while still reading the legacy `companion_cat_theme` key as fallback.

Still incomplete or not fully verified:

- `TimerEngine` still owns tray, notification, stats, persistence, and IPC side effects; full orchestration extraction is not complete.
- Native bridge channel names are still mixed. Several macOS and Windows paths still use `com.breakmate.macos/bridge` and `com.breakmate.macos/companion_data`.
- Test coverage is still thin. `test/core_behavior_test.dart` still contains placeholder timer/settings tests.
- Dart/Flutter tooling hangs locally, so analyzer/test/format validation is not reliable yet.
- Break overlay templates are partially split, but large template files still need controller/widget extraction.
- Storage still depends on `SharedPreferences` style key/value access for many app domains. This should move to ObjectBox for faster structured reads/writes, typed queries, better migrations, and cleaner repositories.
- The current UI needs a modern minimal redesign focused on easier navigation, clearer daily actions, cleaner settings, smoother transitions, and stronger accessibility.

## Key Findings

1. The timer path rebuilds too broadly. `TimerEngine` calls `notifyListeners()` every second, and the app-level `ListenableBuilder` listens to the whole timer and overlay service. This can rebuild more UI than necessary.
2. Stats updates are now debounced and use pure calculator functions, but storage writes still happen in `StatsService` and monthly/yearly aggregation is not implemented.
3. IPC now has typed event models, but string event names are still duplicated in `main.dart`, `dependency_injection.dart`, and some `IpcBridge` helper methods.
4. The background polling isolate still proxies MethodChannel calls through the main isolate. That helps isolate app logic, but it does not fully remove native channel work from the UI isolate.
5. Asset strategy is improved, but `lofi_1.mp3`, full font files, and large tray/source images still dominate the asset tree.
6. Large UI files make changes slower and riskier. Settings sections are split, but the breaks section, overlay templates, and standalone overlay code still need smaller widgets/controllers.
7. Test folders now exist, but most core behavior tests are placeholders. Timer behavior, settings persistence, strict mode, and overlay controls still need real regression tests before deeper refactors.
8. Storage is still too key/value oriented for growing features. Settings, stats, break sessions, exercises, companion preferences, cache metadata, and future exports should use typed local data models with versioned migrations.
9. The UI needs a focused redesign rather than incremental styling changes. The app should prioritize a clean dashboard, fast tray popover, searchable settings, consistent visual hierarchy, and subtle motion that can be disabled.

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

- [x] Implement ObjectBox as the app's local storage engine.
  - Use ObjectBox for analytics, sessions, exercises, settings snapshots, companion preferences, and future search/export.
  - Verify current ObjectBox package support for macOS and Windows before implementation.
  - Record the decision in `docs/architecture.md` with migration risks and rollback plan.
- [x] Replace raw `SharedPreferences` storage access with typed repositories.
  - Settings repository.
  - Stats repository.
  - Break session repository.
  - Exercise repository.
  - Companion preferences repository.
  - Cache metadata repository.
- [x] Add storage abstraction before migrating data.
  - Define `LocalStore` or `AppDatabase` interface.
  - Keep storage engine details out of widgets and feature services.
  - Provide an in-memory fake for unit tests.
  - Keep legacy `StorageService` as an adapter during migration.
- [x] Add database schemas/models with explicit versions.
  - Settings snapshot.
  - Daily stats.
  - Weekly/monthly/yearly aggregates.
  - Break sessions with start/end/skip/postpone reason.
  - Wellness actions and exercises.
  - Companion preferences and theme cache metadata.
  - App metadata and migration state.
- [x] Add a safe migration from existing key/value data.
  - Read old keys once.
  - Write typed records.
  - Mark migration complete.
  - Keep old keys for one release as rollback safety.
  - Add a manual repair path if migration fails.
- [x] Improve storage performance.
  - Batch writes for analytics and settings sliders.
  - Use lazy boxes or indexes where supported.
  - Avoid synchronous heavy JSON parsing on startup.
  - Cache hot settings in memory and persist in the background.
  - Flush pending writes on shutdown.
- [x] Add storage observability.
  - Log migration duration in debug builds.
  - Log slow reads/writes above a threshold.
  - Track database size.
  - Add a local storage health report in settings.
- [x] Add backup/export/import support on top of the new storage layer.
  - JSON backup.
  - CSV analytics export.
  - Restore from backup.
  - Validate imports before replacing local data.
  - Keep all exports local-only unless the user explicitly shares them.
- [x] Replace stringly typed IPC events with typed event models.
  - Define event names in one file.
  - Add `toJson` and `fromJson` validation for each payload.
  - Share parsing between main, overlay, and companion isolates.
- [x] Add IPC failure handling.
  - Track last successful event per channel.
  - Add retries for important events like break start/end.
  - Add debug logs only behind a verbose flag to avoid log noise.
- [ ] Add tests for core behavior.
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
- [x] Split break overlay templates into smaller widgets.
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
- [x] Move pet tray icon generation out of `pet_asset_loader.dart`.
  - Keep image loading separate from generated tray icon cache.
- [x] Add barrel files only where they reduce import noise.
  - Avoid broad barrels that hide dependencies in core services.
- [x] Standardize naming.
  - Use companion/pet consistently instead of mixing cat/pet keys.
  - Use break template IDs consistently across settings and UI.
- [x] Document ownership boundaries.
  - `core` has platform/services/utilities.
  - `features` own business behavior.
  - `shared` owns visual primitives.

## Priority 5: UX Improvements

- [ ] Redesign the app around a modern minimal desktop UI.
  - Quiet, productivity-focused visual style.
  - Clear typography scale with fewer oversized headings.
  - More spacing consistency and fewer visually heavy panels.
  - Neutral surfaces with restrained accent colors for action states.
  - Better contrast in light and dark themes.
  - Avoid decorative clutter that distracts from break decisions.
- [ ] Create a cohesive design system.
  - App shell layout.
  - Navigation rail or compact sidebar.
  - Buttons, segmented controls, toggles, sliders, dropdowns, and cards.
  - Toasts, dialogs, popovers, and inline validation.
  - Status chips for running, paused, meeting-aware, strict, and companion states.
  - Empty, loading, error, and offline/unavailable states.
- [ ] Improve information architecture and navigation.
  - Dashboard.
  - Breaks and profiles.
  - Companion.
  - Analytics.
  - Wellness library.
  - Settings.
  - About and updates.
  - Keep high-frequency actions reachable from dashboard and tray popover.
- [ ] Replace the current dashboard with a clearer "Today" workspace.
  - Large but restrained next-break timer.
  - Current focus session status.
  - Completed, skipped, postponed, and snoozed break summary.
  - Smart recommendation with one primary action.
  - Meeting/focus pause status.
  - Companion status with quick toggle.
  - Daily wellness progress without guilt-based language.
- [ ] Modernize settings UX.
  - Search settings.
  - Group settings by domain and user intent.
  - Add reset-to-default per section.
  - Add inline permission status and repair actions.
  - Add save feedback only when needed.
  - Reduce long scroll fatigue with section navigation.
  - Move advanced/debug controls behind an advanced section.
- [ ] Redesign tray/menu-bar popover.
  - Current timer state.
  - Start/pause/reset.
  - Snooze options.
  - Trigger break now.
  - Toggle companion.
  - Toggle quiet mode.
  - Show the reason for smart pause.
- [ ] Add polished transitions and motion.
  - Subtle route transitions.
  - Animated timer/progress changes without layout shift.
  - Smooth settings section changes.
  - Tray popover enter/exit animation.
  - Break overlay transition from warning to active break.
  - Companion state changes with low-distraction animation.
  - Respect reduced-motion and low-power settings.
- [ ] Add a modern minimal break overlay refresh.
  - Cleaner countdown layouts.
  - Better skip/postpone affordances when strict mode allows them.
  - Clear "why now?" explanation.
  - Better keyboard access.
  - High contrast and reduced blur options.
  - Consistent template selector and preview.
- [ ] Improve analytics presentation.
  - Simple trend cards.
  - Daily and weekly views.
  - Skip/postpone patterns.
  - Break completion quality.
  - Wellness actions over time.
  - Explain scores in plain language.
- [ ] Add first-run and upgrade flows.
  - First-run onboarding for break profile, strictness, notifications, smart detection, and companion.
  - Migration complete screen if storage is upgraded.
  - Permission education shown only when needed.
  - Quick restore defaults option if migrated settings look wrong.
- [ ] Add accessibility and keyboard polish as part of the redesign.
  - Full keyboard navigation.
  - Predictable focus order.
  - Screen-reader labels for controls and charts.
  - Large text support.
  - Color contrast audit.
  - Escape behavior when strict mode is off.
  - No motion-only status changes.
- [ ] Add UI quality gates.
  - Screenshot review for dashboard, settings, tray popover, analytics, and break overlay.
  - Widget tests for main navigation and critical settings flows.
  - Golden tests for major states after design stabilizes.
  - Manual checks on macOS and Windows at common desktop sizes.
  - Verify no text overflow at large text scale.
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
- [ ] Redesign settings around a modern minimal layout.
  - Section navigation.
  - Search and keyboard shortcuts.
  - Clear primary/secondary actions.
  - Inline explanations for advanced settings.
  - Better mobile-width and narrow-window behavior.

### Storage Layer

- [ ] Add ObjectBox after a desktop support and benchmark check.
- [ ] Add a single storage abstraction consumed by repositories.
- [ ] Move settings from raw keys to typed records.
- [ ] Move stats from JSON blobs to typed daily/session records.
- [ ] Move exercises and wellness library data to typed records.
- [ ] Move companion preferences and generated asset metadata to typed records.
- [ ] Add migration from existing `SharedPreferences` keys.
- [ ] Add rollback-safe migration markers and backups.
- [ ] Add in-memory fake storage for tests.
- [ ] Add read/write benchmarks for hot paths.
- [ ] Add corrupt-database recovery and local repair UI.
- [ ] Add export/import built on top of typed records.

### UI Shell And Design System

- [ ] Create a modern app shell with clear navigation.
- [ ] Define reusable design primitives in `shared/widgets`.
- [ ] Replace inconsistent cards and controls with standard components.
- [ ] Add route transitions and popover transitions.
- [ ] Add reduced-motion support at theme/app-shell level.
- [ ] Add dark/light theme tokens and high-contrast variants.
- [ ] Add screenshot/golden coverage after the design stabilizes.
- [ ] Keep dashboard, tray popover, settings, analytics, and overlay visually consistent.

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
- [ ] Unit tests for storage migration from legacy keys to typed records.
- [ ] Unit tests for ObjectBox repository adapters using fake or temp databases.
- [ ] Unit tests for storage corruption recovery.
- [ ] Unit tests for stats scoring.
- [ ] Unit tests for IPC event parsing.
- [ ] Unit tests for pet state machine transitions.
- [ ] Widget tests for countdown UI.
- [ ] Widget tests for settings sections after split.
- [ ] Widget tests for redesigned navigation shell.
- [ ] Widget tests for settings search and reset-to-default.
- [ ] Widget tests for tray popover quick actions.
- [ ] Widget tests for break overlay controls.
- [ ] Golden tests for critical overlay templates.
- [ ] Golden tests for dashboard, settings, analytics, tray popover, and break overlay in light/dark themes.
- [ ] Integration test for start -> pre-break -> break -> finish.
- [ ] Integration test for skip and postpone when strict mode is off.
- [ ] Integration test proving strict mode blocks skip paths.
- [ ] Integration test for meeting detection pause/resume using fake bridge.
- [ ] Integration test for storage migration on first launch after update.
- [ ] Smoke test for companion theme switching.
- [ ] Smoke test for app startup with corrupt storage values.

## Build And Release Backlog

- [ ] Add CI workflow for analyze and tests.
- [ ] Add CI workflow for macOS build if runner is available.
- [ ] Add CI workflow for Windows build if runner is available.
- [ ] Add CI smoke check for storage migration.
- [ ] Add CI asset budget report output.
- [ ] Add UI screenshot artifact generation for release candidates.
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
- [ ] Document the selected local database engine and its on-disk files.
- [ ] Add encrypted or OS-protected storage option if sensitive future data is added.
- [ ] Ensure backup/export files never include private active app names unless explicitly enabled.
- [ ] Make Sentry opt-in or clearly disclosed if release telemetry is used.
- [ ] Avoid logging active app names by default.
- [ ] Avoid logging user settings values that could reveal work habits.
- [ ] Keep team features anonymous and optional if implemented.

## Suggested Execution Order

1. Fix analyzer timeout and add basic test/analysis CI.
2. Add ObjectBox and a storage abstraction with tests.
3. Migrate settings, stats, exercises, companion preferences, and cache metadata to typed storage.
4. Add timer, stats, settings, storage migration, and IPC tests.
5. Refactor timer rebuild/listener behavior.
6. Debounce stats writes and tray updates through the new repositories.
7. Build the modern minimal design system and navigation shell.
8. Redesign dashboard, tray popover, settings, analytics, and break overlay.
9. Reduce overlay/template timers and hidden animations.
10. Optimize assets and audio bundle size.
11. Split remaining large overlay/settings files.
12. Type remaining native bridge capabilities and unify channel names.
13. Add onboarding, today dashboard, and smarter recommendations.
14. Add optional advanced features like calendar, team, and mobile sync.

## Validation Checklist Before Release

- [ ] `flutter analyze` completes successfully within the target time.
- [ ] Unit tests cover timer, settings, stats, and IPC parsing.
- [ ] Storage migration succeeds from existing key/value data to typed ObjectBox records.
- [ ] Storage reads/writes meet performance targets for startup, settings save, and analytics updates.
- [ ] App can recover from corrupt or missing local database files.
- [ ] Desktop smoke test on macOS and Windows.
- [ ] Modern UI screenshot review passes for dashboard, settings, analytics, tray popover, and break overlay.
- [ ] Main navigation is usable by keyboard.
- [ ] Reduced-motion mode disables non-essential route, overlay, and companion animations.
- [ ] No text overflow at common desktop sizes and large text scale.
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
