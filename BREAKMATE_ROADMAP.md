# BreakMate Roadmap

Last reviewed: 2026-05-31

## Project Snapshot

BreakMate is a Flutter desktop wellness app focused on healthier work rhythm, break enforcement, local analytics, smart pause detection, and a Flame-powered desktop companion. The product is already feature-rich; the next roadmap should make the app feel faster, calmer, easier to configure, and safer to evolve.

Current evidence from this review:

- 160 Dart files under `lib/`.
- No active files under `test/` were found during this review.
- About 21 MB under `assets/`.
- Largest asset groups: `assets/slideshow/` at about 13 MB, `assets/music/lofi_1.mp3` at about 4 MB, and Inter fonts at about 1.6 MB.
- Largest non-generated Dart files: `breaks_settings_section.dart`, `dashboard_page.dart`, `standalone_break_overlay.dart`, `companion_interactive_template.dart`, `settings_repository.dart`, `pet_state_machine.dart`, `pet_asset_loader.dart`, `timer_engine.dart`, `settings_model.dart`, and `classic_slideshow_template.dart`.
- Main runtime hubs: `TimerEngine`, `TimerOrchestrator`, `BreakController`, `TrayManagerService`, `CompanionOverlayController`, `PetAssetLoader`, `SettingsRepository`, `StatsService`, native bridge services, and overlay templates.
- Main UX hubs: dashboard, tray/menu-bar popover, break settings, companion settings, break overlays, onboarding, analytics, and data management.

## Product Direction

BreakMate should feel like a quiet desktop health utility, not a heavy dashboard. The user should understand three things immediately:

- What state am I in right now?
- Why is the app asking me to take a break?
- What is the least disruptive action I can take?

The best next improvements are not more decorative UI or more settings. The priority is fewer confusing decisions, faster feedback, better defaults, reliable detection, and clear user control.

## North-Star UX Principles

- Make the timer and next break reason visible anywhere the user can act.
- Prefer one recommended action over many equal-looking buttons.
- Keep strict and locked modes explicit, predictable, and reversible only where the selected intensity allows it.
- Keep companion behavior ambient and explainable; it should support the timer instead of competing with it.
- Keep every smart feature local-first and privacy-readable.
- Respect meetings, presentations, low battery, reduced motion, high contrast, and keyboard navigation.

## Current Risks

1. **Test coverage is too thin.** The roadmap previously referenced placeholder tests, but the current checkout has no active test files. Timer transitions, strict mode, settings persistence, storage migration, IPC parsing, and analytics scoring need regression coverage before larger refactors.
2. **Startup still does too much.** Dependency injection initializes storage, notifications, display services, smart detection, stats, tray, companion controller, pet discovery, and tray icon pre-cache near startup. Optional services should be lazy or setting-gated.
3. **High-frequency state can still rebuild too much UI.** `TimerEngine` remains a `ChangeNotifier` with a one-second tick and many `notifyListeners()` calls. Timer text and progress should update without rebuilding broad dashboard or overlay trees.
4. **Settings complexity is concentrated.** `breaks_settings_section.dart` is the largest hand-written feature file and mixes profiles, intervals, intensity, display behavior, preview UI, file picking, and template controls.
5. **Break templates contain behavior and presentation together.** Several templates still own timers, local state, animations, and large build methods.
6. **Asset budget has regressed past the stated target.** `docs/dev-checks.md` targets assets under 20 MB, but the current tree is about 21 MB, mostly from slideshow images.
7. **Performance baseline still needs real numbers.** `docs/performance-baseline.md` contains measurement instructions but no filled measurements.
8. **Feature count may exceed first-run comprehension.** Calendar awareness, wellness content, companion controls, strictness, templates, music, analytics, and smart detection need progressive disclosure.

## Priority 0: Measurement And Release Confidence

These items should happen before large UX or architecture changes.

- [ ] Fill `docs/performance-baseline.md` with real measurements from a profile or release build.
  - Cold start to first dashboard frame.
  - Dependency initialization duration.
  - Break overlay open latency.
  - Companion first visible frame.
  - Idle CPU and memory with dashboard hidden.
  - Settings scroll frame time.
  - Companion active and throttled CPU.
- [ ] Add a repeatable local command for asset budget reporting.
  - Current total: about 21 MB.
  - Target before release: under 20 MB unless a release note justifies the increase.
  - Track top 20 assets in CI or a local pre-release script.
- [ ] Restore a useful `test/` suite.
  - Timer start, pause, resume, reset.
  - Pre-break warning transition.
  - Long break scheduling.
  - Strict and locked skip/postpone rules.
  - Settings defaults and persistence.
  - Stats scoring and one-streak-per-day behavior.
  - IPC event parsing and invalid payload handling.
- [ ] Add smoke tests or scripted manual checks for macOS and Windows.
  - Tray icon appears.
  - Dashboard opens.
  - Start/pause/reset works.
  - Break now opens overlay.
  - Strict overlay blocks only as configured.
  - Companion can show, hide, click-through, and change theme.
- [ ] Keep analyzer and formatter checks documented and timed.
  - `flutter analyze`.
  - `dart format --set-exit-if-changed .`
  - `flutter test`.

## Priority 1: Core UX Improvements

### Dashboard

- [ ] Make the dashboard a compact "Today" command center.
  - Current timer state.
  - Time until next break.
  - Reason for the next break.
  - Smart pause reason, if paused by meeting, idle, focus mode, or calendar.
  - Today's completed, skipped, postponed, and snoozed breaks.
  - One recommended adjustment based on recent behavior.
- [ ] Reduce visual weight in timer cards.
  - Keep timer text stable so layout does not shift.
  - Use smaller status chips for strict, quiet, meeting-aware, and companion states.
  - Avoid nested card sections where a simple row or band is enough.
- [ ] Make calendar awareness more actionable.
  - Show the next meeting conflict only when it affects breaks.
  - Offer "snooze until meeting ends" or "take break before meeting" when relevant.
  - Cache permission status so the dashboard does not repeatedly trigger permission checks.

### Tray / Menu-Bar Popover

- [ ] Make tray actions feel instant.
  - Use cached timer state for initial render.
  - Show immediate feedback after pause, resume, reset, break now, snooze, quiet mode, and companion toggle.
  - Avoid synchronous service lookups in frequently rebuilt popover widgets.
- [ ] Add a clear pause reason line.
  - Manual pause.
  - Meeting detected.
  - Idle detected.
  - Calendar conflict.
  - Focus mode.
  - Low battery quiet mode.
- [ ] Add quick snooze options.
  - 5 minutes.
  - 15 minutes.
  - Until current meeting ends.
  - Until active full-screen app exits, if supported safely.

### Break Overlay

- [ ] Every overlay template should answer four questions.
  - Why now?
  - How long remains?
  - What should I do?
  - Which actions are blocked by strict or locked mode?
- [ ] Normalize skip and postpone behavior.
  - Disabled controls should explain the current intensity rule.
  - Repeated skips should suggest changing the break profile instead of shaming the user.
- [ ] Add reduced-motion and high-contrast variants for every template.
  - Disable Ken Burns.
  - Disable floating particles and companion bubble motion.
  - Preserve countdown readability.
- [ ] Split large templates into controllers plus pure widgets.
  - `standalone_break_overlay.dart`.
  - `companion_interactive_template.dart`.
  - `classic_slideshow_template.dart`.
  - `soft_floating_widget_template.dart`.
  - `guided_breathing_widget.dart`.
  - `eye_sync_game_widget.dart`.

### Settings

- [ ] Make settings searchable and task-oriented.
  - Search by setting label, synonym, and feature area.
  - Add "reset section" and "restore recommended defaults."
  - Group advanced/debug options away from everyday settings.
- [ ] Split `breaks_settings_section.dart` further.
  - Profile selector.
  - Custom interval editor.
  - Intensity and enforcement.
  - Display behavior.
  - Template picker and preview.
  - Music and asset selection.
- [ ] Add inline validation and dependency warnings.
  - Long break interval must be greater than short break interval.
  - Locked mode requires accessibility/full-screen permissions where applicable.
  - Calendar features require calendar permission.
  - Music controls should be hidden or disabled when audio is off.
- [ ] Add settings change feedback that is useful, not noisy.
  - Immediate visual state update.
  - Debounced persistence for sliders and cosmetic changes.
  - Explicit success or failure only for permission, import/export, and update operations.

### Companion

- [ ] Make companion state explainable.
  - Sleeping because meeting mode is active.
  - Quiet because focus mode is active.
  - Alert because a break is approaching.
  - Playful because the user interacted.
- [ ] Add a low-distraction mode.
  - Lower FPS.
  - Fewer behavior changes.
  - No speech bubbles.
  - Click-through enabled by default during focus.
- [ ] Improve pet picker performance.
  - Load only selected pet at startup.
  - Load previews when picker opens.
  - Cache generated icons with versioned invalidation.
  - Show a lightweight placeholder while decoding assets.

## Priority 2: Runtime Performance

- [ ] Split high-frequency countdown updates from low-frequency timer state.
  - Keep a small countdown listenable for per-second UI.
  - Keep settings, active break metadata, and mode changes in lower-frequency state.
  - Use selectors or `ValueListenableBuilder` for timer text and progress only.
- [ ] Finish moving side effects out of `TimerEngine`.
  - Tray updates.
  - Notifications.
  - Stats writes.
  - IPC dispatch.
  - Sleep/wake recovery.
  - Activity tracking.
- [ ] Gate optional services at startup.
  - Start smart detection only when enabled.
  - Start meeting stream only when meeting-aware mode is enabled.
  - Defer calendar permission checks until dashboard or settings need calendar data.
  - Defer pet discovery and non-selected pet loading until companion settings open.
- [ ] Audit all periodic timers.
  - `TimerEngine` one-second tick.
  - `BackgroundPollingService` idle and smart polling.
  - `CompanionBehaviorEngine` behavior loop.
  - `TrayManagerService` tray animation timer.
  - Break overlay local timers.
  - Dashboard calendar refresh timer.
- [ ] Add lifecycle and visibility guards.
  - Stop or throttle template timers when overlay is hidden.
  - Stop dashboard refresh timers when dashboard is not visible.
  - Lower companion work when click-through and idle.
  - Suspend nonessential timers during locked breaks.
- [ ] Keep expensive image work off hot paths.
  - Cache decoded slideshow image providers.
  - Generate smaller slideshow variants.
  - Avoid decoding pet assets repeatedly after theme switches.

## Priority 3: Asset And Bundle Optimization

- [ ] Reduce slideshow asset size first.
  - Current slideshow directory is about 13 MB.
  - Generate desktop-sized WebP or compressed JPEG variants.
  - Keep original source-quality images outside the Flutter asset bundle.
- [ ] Keep audio optional.
  - One bundled default track is acceptable at about 4 MB.
  - Add optional downloadable audio packs only after local pack management exists.
  - Do not initialize audio resources until music is enabled or a break starts.
- [ ] Subset fonts before release if installer size matters.
  - Current Inter fonts are about 1.6 MB.
  - Keep only used weights and glyph ranges.
- [ ] Keep generated DMG and source art out of runtime assets unless used in app UI.
- [ ] Add a clear asset budget table to release notes.

## Priority 4: Architecture And Data

- [ ] Decide the long-term persistence boundary.
  - The codebase currently includes Hive, ObjectBox, and key/value style storage paths.
  - Document which data lives in which store.
  - Avoid new feature code reading raw keys directly from widgets.
- [ ] Create typed repositories for growing feature domains.
  - Settings.
  - Break sessions.
  - Daily stats and aggregates.
  - Companion preferences.
  - Wellness library and completed actions.
  - Cache metadata.
- [ ] Add migration and repair UX.
  - Show local-only migration status.
  - Let users export before repair.
  - Keep last-known-good settings and stats backup.
- [ ] Keep IPC event names and payloads centralized.
  - One event name source.
  - Payload versioning.
  - Validation on receive.
  - Debug logs behind a verbose flag.
- [ ] Document native capability status.
  - Notifications.
  - Calendar.
  - Meeting detection.
  - Focus mode.
  - Launch at startup.
  - Accessibility/full-screen enforcement.

## Priority 5: Accessibility And Quality Gates

- [ ] Add keyboard coverage for all primary flows.
  - Dashboard timer actions.
  - Tray popover actions.
  - Settings navigation and search.
  - Break overlay skip/postpone where allowed.
  - Dialog cancel/confirm.
- [ ] Verify screen-reader labels.
  - Timer state.
  - Progress ring values.
  - Chart summaries.
  - Companion state and toggles.
  - Strict mode controls.
- [ ] Verify responsive and large-text behavior.
  - No overflow at large text scale.
  - Buttons do not clip labels.
  - Settings rows wrap cleanly.
  - Overlay countdown remains readable.
- [ ] Add screenshot or golden coverage after component cleanup.
  - Dashboard light/dark.
  - Settings search and break profile editor.
  - Tray popover running, paused, and smart-paused.
  - Strict break overlay.
  - Companion picker.
  - Analytics summary.

## Priority 6: Feature Roadmap

### Next Features

- [ ] Adaptive break planner.
  - Adjust recommendations based on skips, postpones, meeting density, time of day, and session length.
  - Recommend settings changes without changing them automatically.
- [ ] Calendar-aware break windows.
  - Suggest breaks between meetings.
  - Avoid triggering strict breaks during accepted meetings.
  - Show a clear reason when a break is moved.
- [ ] Local privacy report.
  - What is detected.
  - What is stored.
  - What leaves the machine.
  - How to disable each data source.
- [ ] Guided recovery after system sleep or long idle.
  - Count away time as break.
  - Resume focus.
  - Reset session.
  - Start a gentle break.
- [ ] Wellness action library.
  - Eye rest.
  - Wrist mobility.
  - Neck and posture.
  - Breathing.
  - Hydration.
  - Short walk.

### Later Features

- [ ] Optional template and audio packs.
  - Keep core installer small.
  - Let users install visual or audio packs locally.
- [ ] Companion progression without pressure.
  - Unlock animations or accessories through healthy consistency.
  - Avoid punitive streak mechanics.
- [ ] Team mode research only.
  - Shared break rooms.
  - Anonymous aggregate wellness trends.
  - No individual surveillance metrics.
- [ ] Mobile companion research only.
  - Remote break reminder.
  - Optional sync.
  - Local-first privacy model.

## Suggested Execution Order

1. Fill performance baseline and restore the test suite.
2. Split high-frequency timer listenables and add timer transition tests.
3. Refactor break settings into smaller sections and add settings search/reset UX.
4. Gate optional startup services and lazy-load companion/slideshow assets.
5. Reduce slideshow assets below the 20 MB budget target.
6. Normalize dashboard, tray popover, and break overlay status language.
7. Add accessibility checks and screenshot coverage for the stabilized UI.
8. Build adaptive break planning and calendar-aware break windows.

## Definition Of Done For The Next Release

- `flutter analyze` completes without errors.
- `flutter test` runs meaningful tests for timer, settings, stats, strict mode, and IPC.
- `docs/performance-baseline.md` has real before/after measurements.
- Asset tree is under the agreed budget or release notes explain why not.
- Dashboard, tray popover, settings, and break overlay pass large-text and keyboard checks.
- Startup does not eagerly load disabled optional features.
- The user can understand why a break started and what actions are available in under five seconds.
