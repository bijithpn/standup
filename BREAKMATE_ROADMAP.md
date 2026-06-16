# BreakMate Roadmap

Last reviewed: 2026-06-16

## Project Snapshot

BreakMate is now a fairly broad Flutter desktop wellness product with timer orchestration, break overlays, tray/menu-bar controls, analytics, calendar-aware logic, contextual wellness guidance, and a Flame-powered companion.

Current evidence from this review:

- App version in `pubspec.yaml`: `1.4.0+33`
- Current `main` HEAD: post-`v1.2.1` packaging/update follow-up work (`feat:new dmg updated`)
- Dart files under `lib/`: 172
- Active test files under `test/`: 19
- Asset tree size: about 21 MB
- Largest asset groups: `assets/slideshow/` about 13 MB, `assets/music/` about 4.0 MB, `assets/fonts/` about 1.6 MB
- Largest non-generated Dart files include `dashboard_page.dart`, `standalone_break_overlay.dart`, `pet_state_machine.dart`, `break_appearance_settings.dart`, `timer_engine.dart`, `companion_interactive_template.dart`, `pet_asset_loader.dart`, `settings_repository.dart`, `main_layout.dart`, and `tray_manager_service.dart`
- Major feature areas present in the repo: dashboard, menu-bar/tray, break overlay, break system, companion, analytics, onboarding, settings, wellness, notifications, themes, tracking, and blog/wellness content surfaces

## What Landed Recently

### Already shipped

- `v1.1.0` through `v1.1.4` delivered timer/runtime refactoring, companion behavior updates, onboarding persistence fixes, storage hardening, and macOS data migration.
- `v1.2.0` added contextual wellness guidance, calendar-aware break planning, personal goals, wind-down support, wellness library surfaces, companion consistency progression, and a local privacy report.
- `v1.2.1` replaced the macOS calendar plugin path with a native EventKit bridge, improved permission recovery, grouped dashboard calendar views, and fixed calendar initialization/meeting-detection failures.
- `v1.3.0` brought an enhanced dashboard with compact status chips, pause context, settings search, and manual smoke-check documentation.
- `v1.4.0` delivered the Desktop Companion Engine overhaul, an Interactive Environment Builder with live previews, a high-performance interactive PiP overlay, and Flash Notifications for ambient awareness.

### Present on `main` after `v1.4.0`

- DMG packaging and release-path follow-up commits are present after the `v1.4.0` tag.
- Appcast/release automation is still active and worth treating as an ongoing release-safety surface.

## Product Direction

BreakMate should feel like a quiet desktop utility with strong defaults, clear reasoning, and low-friction control. The app already has enough surface area. The next phase should reduce ambiguity, improve release confidence, and make existing features easier to trust.

The user should be able to answer these quickly:

- What state is the timer in right now?
- Why did BreakMate pause, delay, or trigger a break?
- Which actions are available, and which are intentionally blocked?
- Which smart features are active, and what local data do they rely on?

## Current Risks

1. **There is still no meaningful automated test suite.** `test/` is empty, while timer transitions, strict-mode behavior, settings persistence, stats scoring, IPC payloads, and calendar/permission paths all carry regression risk.
2. **Bundle size is still over the stated budget.** Assets remain about 21 MB, with slideshow images as the main target.
3. **Performance documentation is only partly real.** `docs/performance-baseline.md` now exists, but most runtime metrics are still placeholders pending profile or release measurements.
4. **Core UI files are still large.** `dashboard_page.dart`, `standalone_break_overlay.dart`, `companion_interactive_template.dart`, and some settings sections remain substantial maintenance hotspots.
5. **Release automation still has manual edges.** Appcast, release notes, DMG packaging, and version alignment are active workflows and deserve explicit verification on every release.
6. **Startup and background behavior are still complex.** The app coordinates storage, native bridges, tray state, smart detection, companion state, analytics, and overlays; disabled features should not impose the same runtime cost as enabled ones.

## North-Star Priorities

1. Restore release confidence with tests, measurements, and explicit smoke checks.
2. Make existing smart features more explainable before adding new intelligence.
3. Shrink maintenance hotspots by continuing UI/controller splits where files are still oversized.
4. Reduce installer/runtime cost by cutting slideshow asset size and avoiding eager optional initialization.
5. Keep privacy and local-first behavior readable anywhere permissions or detection are involved.

## Priority 0: Release Confidence

- [ ] Rebuild a useful `test/` suite.
  - Timer start, pause, resume, reset, and end-time transitions
  - Pre-break warning and break handoff behavior
  - Strict and locked action availability
  - Settings defaults, persistence, and migration fallback
  - Stats scoring and one-consistency-day-per-day behavior
  - Calendar/permission state mapping
  - IPC payload validation and failure handling
- [/] Keep manual smoke checks current for macOS and Windows.
  - `docs/dev-checks.md` is present and useful
  - It still needs to remain aligned with the newest calendar, packaging, and companion flows
- [/] Fill `docs/performance-baseline.md` with real runtime captures.
  - Static baseline exists
  - Profile or release measurements are still pending
- [ ] Add a short release checklist that explicitly verifies:
  - `pubspec.yaml` version/build
  - appcast metadata
  - release notes
  - DMG/output paths
  - installer or archive naming

## Priority 1: Core UX Tightening

### Dashboard

- [/] Keep the dashboard as a compact command center.
  - Current timer and next-break context exist
  - Calendar grouping and permission recovery now exist
  - Continue reducing density and large-file complexity in `dashboard_page.dart`
- [x] Surface smart pause and meeting context clearly.
- [x] Show actionable calendar conflict handling rather than passive status only.
- [ ] Add one clear recommended action when recent behavior shows repeated skips or postpones.

### Tray / Menu-Bar

- [x] Quick timer actions and pause reasons are already present.
- [ ] Validate that every fast action has immediate visual feedback on both macOS and Windows.
- [ ] Keep the tray popover resilient under DPI scaling and long localized labels.

### Break Overlay

- [/] Continue separating presentation from behavior.
  - Large templates still exist under `lib/features/break_overlay/presentation/templates/`
  - `standalone_break_overlay.dart` remains a large hotspot
- [x] Contextual break reasoning is now part of the product direction and recent features.
- [ ] Verify every template communicates:
  - why the break started
  - how long remains
  - what the user should do
  - which controls are disabled by intensity rules

### Settings

- [/] Settings were already split substantially, but complexity remains high.
  - `lib/features/settings/presentation/sections/` now holds smaller slices
  - `break_appearance_settings.dart` is still large enough to merit more decomposition
- [x] Calendar and permission-aware settings now exist.
- [ ] Add clearer separation between daily-use settings and advanced/debug/release-facing options.

## Priority 2: Runtime And Performance

- [/] Keep optional services gated by settings and visibility.
  - This has improved across recent releases
  - It still needs verification with actual startup and idle measurements
- [/] Continue isolating high-frequency timer updates from broad UI rebuilds.
  - Previous refactors landed
  - Remaining proof should come from profile traces, not assumption
- [ ] Audit overlay and companion timers for hidden-window throttling and background cost.
- [ ] Confirm calendar, smart detection, and companion initialization are lazy where possible.
- [ ] Add measured before/after notes for any future runtime work instead of qualitative claims only.

## Priority 3: Asset And Packaging

- [ ] Reduce slideshow bundle size below the current level.
  - Keep runtime-ready images in the app bundle
  - Move original or oversized source art outside Flutter asset declarations
- [ ] Keep audio optional at runtime.
  - Do not initialize audio until needed
  - Avoid adding more bundled tracks before pack management exists
- [ ] Consider font subsetting if release artifacts continue to grow.
- [ ] Treat DMG and appcast generation as first-class release surfaces, not script afterthoughts.

## Priority 4: Architecture And Data Boundaries

- [x] Document the real persistence boundary clearly.
  - The repo contains ObjectBox models plus simpler settings/key-value paths
  - Future feature work should not make widgets responsible for raw storage rules
- [x] Keep native bridge contracts centralized and versioned.
  - Calendar
  - focus mode
  - meeting detection
  - overlay control
  - app tracking
  - display management
- [ ] Continue shrinking ownership hotspots in:
  - dashboard
  - break overlay templates
  - timer engine
  - companion asset loading
  - settings appearance/editor sections

## Priority 5: Accessibility And Quality Gates

- [ ] Add keyboard coverage for dashboard, tray, settings, dialogs, and allowed break actions.
- [ ] Verify large-text and reduced-motion behavior across dashboard, overlay, and settings surfaces.
- [ ] Add stronger semantics for timer state, progress indicators, charts, companion controls, and strict-mode messaging.
- [ ] Add screenshot or golden coverage once the main UI hotspots stabilize.

## Feature Roadmap Status

### Now shipping

- [x] Calendar-aware break planning
- [x] Local privacy report
- [x] Wellness activity library
- [x] Companion progression based on consistency rather than punitive streak pressure
- [x] Wind-down and end-of-day wellness support
- [x] Desktop Companion Engine with advanced behaviors
- [x] Interactive Environment Builder
- [x] High-performance Interactive PiP Overlay
- [x] Flash Notifications for ambient break awareness

### Next feature candidates

- [ ] Adaptive break planner that recommends changes without silently mutating user settings
- [ ] Guided recovery after system sleep or long idle
- [ ] Optional local template/audio packs to keep the core installer small
- [ ] Predictive Fatigue AI to show fatigue behaviors before exhaustion

### Research only

- [ ] Team mode with aggregate-only wellness data
- [ ] Mobile companion or cross-device sync
- [ ] More advanced companion adaptation that remains local-first and explainable

## Suggested Execution Order

1. Restore automated tests for timer, settings, stats, and calendar permission flows.
2. Capture real performance numbers in `docs/performance-baseline.md`.
3. Reduce slideshow asset size and verify release artifact paths end to end.
4. Continue breaking up `dashboard_page.dart`, overlay templates, and large settings sections.
5. Tighten tray/dashboard explanations for smart pauses, meeting conflicts, and disabled actions.
6. Add accessibility and screenshot coverage once UI structure is a bit more stable.

## Definition Of Done For The Next Release

- `flutter analyze` completes cleanly.
- `flutter test` covers timer, settings, stats, strict-mode rules, and calendar/permission flows.
- `docs/performance-baseline.md` includes real measured startup, frame, memory, and idle-cost data.
- Asset size is reduced or the release notes explicitly justify the budget overrun.
- Release metadata, appcast, notes, and packaging outputs all align to one version/build.
- Dashboard, tray, settings, and overlay flows explain state and blocked actions clearly in normal and reduced-motion use.
