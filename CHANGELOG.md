# Changelog

All notable changes to BreakMate are documented in this file.

## Tag And Version Index

| Tag | Version | Build | Date | Summary |
|---|---:|---:|---|---|
| `v1.3.0` | 1.3.0 | 32 | 2026-06-02 | Enhanced Dashboard and Settings Experience |
| `v1.2.1` | 1.2.1 | 31 | 2026-06-01 | Native macOS Calendar and Permission Recovery |
| `v1.2.0` | 1.2.0 | 30 | 2026-05-31 | Contextual Intelligence and Personal Wellness |
| `v1.1.4` | 1.1.4 | 29 | 2026-05-31 | Onboarding persistence and macOS storage stability |
| `v1.1.3` | 1.1.3 | 28 | 2026-05-27 | Startup stability, Sentry dev isolation, and Sparkle version alignment |
| `v1.1.2` | 1.1.2 | 27 | 2026-05-27 | UX polish, smart notification visuals, and micro-break integration |
| `v1.1.1` | 1.1.1 | 26 | 2026-05-27 | Minor stability, companion memory, and pet animation fixes |
| `v1.1.0` | 1.1.0 | 25 | 2026-05-27 | Performance refactoring and Pet Fatigue AI |
| `v1.0.1` | 1.0.1 | 24 | 2026-05-26 | Performance and stability update |
| `v1.0.0` | 1.0.0 | 1 | 2026-05-26 | Initial BreakMate release and rebrand |

Note: the local Git tags show `v1.1.0` and `v1.1.1` on the same commit, and `v1.1.4` and `v1.2.0` on the same merge commit. The release entries below preserve the intended appcast/package version history and feature descriptions.

## [Unreleased]

## [1.3.0] - 2026-06-02

Tags: `v1.3.0`  
Build: `32`  
Release title: Enhanced Dashboard and Settings Experience

### Added

- Improved the dashboard with compact status chips, next-break reasoning, pause context, and actionable calendar conflict controls.
- Improved tray/menu-bar quick actions with pause reason, quiet/companion toggles, feedback, and 5/15 minute snooze actions.
- Added break overlay context explaining why the break started, expected action, and strict/locked mode restrictions.
- Added settings search, section reset controls, and inline dependency warnings.
- Added companion low-distraction mode and visible companion state explanations.
- Added a static performance baseline and repeatable asset budget report with category breakdowns.
- Added manual macOS and Windows smoke-check documentation for cases where tests are intentionally skipped.

### Changed

- Rebuilt `BREAKMATE_ROADMAP.md` from the current project state.
- Updated project metrics in the roadmap: 160 Dart files, about 21 MB of assets, no active `test/` files found, and slideshow assets as the largest bundle-size target.
- Reorganized future work around measurement, release confidence, UX, runtime performance, asset optimization, architecture, accessibility, and feature roadmap priorities.
- Updated Graphify graph artifacts after the code changes.

## [1.2.1] - 2026-06-01

Tags: `v1.2.1`  
Build: `31`  
Release title: Native macOS Calendar & Permission Recovery

### Added

- **Native macOS Calendar Bridge:** I implemented a high-performance native bridge using Apple's EventKit framework. This replaces the previous plugin-based approach, ensuring stability on macOS.
- **Advanced Permission Management:** I integrated `permission_handler` and added an explicit "Open Settings" button to the dashboard. This allows you to easily recover from denied calendar permissions by going directly to the OS Privacy settings.
- **Grouped Calendar View:** I updated the Dashboard UI to group upcoming events by date (Today, Tomorrow, etc.) with better visual separators and date headers.
- **Sonoma Privacy Support:** I added the required `NSCalendarsWriteOnlyAccessUsageDescription` and `com.apple.security.personal-information.calendars` entitlements for full compatibility with macOS 14+ Sonoma.
- **Permission State Feedback:** I added success and error toast notifications to provide clear feedback when granting calendar access.

### Fixed

- **Initialization Crash:** I resolved a critical "Bad state" crash that occurred when the app tried to initialize the calendar plugin on macOS.
- **Precision Lookup Bug:** I fixed a bug where the native bridge used hours instead of minutes for event window lookups, which was causing "active meeting" detection to fail.
- **Silent Failure Path:** I fixed an issue where permission requests would fail silently without updating the UI state.

## [1.2.0] - 2026-05-31

Tags: `v1.2.0`  
Build: `30`  
Release title: Contextual Intelligence & Personal Wellness

### Added

- Contextual Wellness Engine for break suggestions based on current work context and active application category.
- App-specific wellness guidance:
  - Coding: posture checks and shoulder relief.
  - Writing: wrist and forearm relief.
  - Browsing: 20-20-20 eye-rest reminders.
  - Meetings: after-call reset suggestions.
- Calendar-aware break planning using `device_calendar_plus`.
- Smart meeting conflict handling so breaks can be delayed when a meeting is active or imminent.
- Personal Goals section for daily focus targets, break-count targets, and sitting limits.
- Smart end-of-day wind-down session at the configured clock-out time.
- Daily summary for focus time, completed breaks, and wellness efficiency.
- Wellness Library page for browsing, favoriting, hiding, and rotating wellness activities.
- Companion progression based on consistency days instead of strict streak pressure.
- Local-only Privacy Report explaining detected signals, stored data, permissions, and local storage behavior.

### Changed

- Migrated calendar integration from `device_calendar` to `device_calendar_plus`.
- Enhanced `AdaptiveBreakService` with contextual awareness.
- Updated break overlay support for wind-down sessions.
- Expanded app navigation for Personal Goals and Wellness Library surfaces.
- Improved companion theme persistence with pet-neutral naming.
- Updated ObjectBox-backed privacy messaging and local data transparency.
- Refined release documentation and project roadmap content for the v1.2.0 feature set.

### Fixed

- Resolved `timezone` dependency conflicts with an explicit override.
- Corrected consistency-day logic so a day counts once toward companion progression.
- Improved settings persistence reliability for new personalization features.
- Cleaned up Dart analysis issues around settings widgets and type usage.
- Replaced deprecated `withOpacity` usage with modern `withValues` calls where applicable.

## [1.1.4] - 2026-05-31

Tags: `v1.1.4`  
Build: `29`  
Release title: Onboarding Persistence & Storage Stability

### Added

- Dual-sync persistence for critical onboarding and break configuration flags.
- High-stability key-value mirror for critical settings recovery.
- Automatic macOS storage migration from `~/Documents/breakmate_db` to `~/Library/Application Support/breakmate_db`.
- Stale database lock-file cleanup for safer startup after crashes.
- Storage lifecycle debug logging for easier diagnosis.
- README documentation for storage and persistence architecture.

### Changed

- Moved macOS app data to the platform-appropriate Application Support directory.
- Hardened `SettingsRepository` load behavior with safer fallback handling.
- Improved JSON decoding resilience for exercises and activity-pattern settings.
- Incremented Sparkle build metadata for update compatibility.

### Fixed

- Fixed onboarding state not persisting across restarts.
- Fixed the onboarding loop caused by stale or failed settings snapshot reads.
- Fixed startup failures caused by stale ObjectBox/LMDB lock files.
- Fixed a missing `dart:async` import for `unawaited` futures.

## [1.1.3] - 2026-05-27

Tags: `v1.1.3`  
Build: `28`  
Release title: Stability, Dev Isolation & Version Alignment

### Changed

- Aligned package and Sparkle metadata to `1.1.3+28`.
- Isolated Sentry initialization to release builds so debug/profile development stays quiet.
- Updated provider wiring for background stats metrics.

### Fixed

- Fixed a startup crash caused by using Provider with a `Listenable`/`Stream` subtype incorrectly.
- Fixed noisy Sentry native SDK and connection warnings during local development.
- Fixed redundant update prompt behavior caused by version/build mismatch.

## [1.1.2] - 2026-05-27

Tags: `v1.1.2`  
Build: `27`  
Release title: User Experience Polish & Smart Notifications

### Added

- Lofi music fade-in and fade-out during pre-break warnings.
- Meeting detection visual indicators in the companion and tray/menu-bar UI.
- Companion "On-Air" style state for meeting-aware mode.
- Micro-break animation mapping for posture and eye-blink reminders.

### Changed

- Improved break transition feedback before overlays appear.
- Connected posture reminders to stretch companion behavior.
- Connected eye-rest reminders to blink companion behavior.
- Updated Sparkle appcast metadata for update delivery.

## [1.1.1] - 2026-05-27

Tags: `v1.1.1`  
Build: `26`  
Release title: Minor Fixes & Improvements

### Changed

- Reduced companion memory footprint during long idle sessions.
- Smoothed pet animation transitions between idle and sleeping states.
- Updated installer build metadata for Sparkle delivery.

### Fixed

- Fixed an edge case where the break timer could reset unexpectedly during rapid app switching.
- Reduced occasional companion animation stutter.

## [1.1.0] - 2026-05-27

Tags: `v1.1.0`  
Build: `25`  
Release title: Performance Refactoring & Pet Fatigue

### Added

- Pet Fatigue AI behavior model based on cumulative daily work duration.
- Companion behavior changes after extended work sessions, including calmer resting and sleeping states.
- Target end-time synchronization across timer, IPC, overlay, and companion surfaces.
- Daily work total synchronization for companion state decisions.
- Background isolate support for OS-level polling.
- Graphify output and project analysis artifacts for dependency and structure review.

### Changed

- Split timer internals into smaller components:
  - `TimerStateData`.
  - `TimerRepository`.
  - `TimerContextManager`.
- Improved background polling by proxying native calls through a safer method-channel pattern.
- Added aggressive asset eviction for companion theme switching.
- Wrapped frequently updated timer and UI regions in `RepaintBoundary`.
- Improved overlay and companion synchronization through IPC.

### Fixed

- Fixed isolate communication crashes around platform services.
- Reduced UI micro-stutters from idle and smart app detection polling.
- Improved companion overlay rendering stability.

## [1.0.1] - 2026-05-26

Tags: `v1.0.1`  
Build: `24`  
Release title: Performance & Stability Update

### Added

- Standardized default break behavior around the 20-20-20 eye-health pattern.
- Appcast generation and release automation improvements for macOS updates.

### Changed

- Parallelized service initialization for faster launch.
- Replaced shared `FlutterEngineGroup` usage for secondary windows with independent Flutter engine instances.
- Optimized statistics heatmap scrolling and viewing.
- Improved reminder behavior so notifications do not steal focus from the active app.
- Modernized macOS release workflow paths, signing steps, and build validation.

### Fixed

- Fixed Sparkle update issues in macOS sandboxed release builds.
- Fixed BreakMate naming in build scripts and CI workflow.
- Fixed appcast feed URL and release-note naming.
- Improved secondary window stability by decoupling engine lifecycle behavior.

## [1.0.0] - 2026-05-26

Tags: `v1.0.0`  
Build: `1`  
Release title: BreakMate Rebrand & Feature Pack

### Added

- Initial BreakMate release after rebrand from the original Standup app.
- macOS menu-bar companion experience for healthy work reminders.
- Desktop pet system with animated cats, dogs, and pixel pets.
- Built-in lofi music player for focus and break sessions.
- Analytics and stats dashboard for productivity and break trends.
- Break reminder system with short and long break intervals.
- Break overlays with countdowns and exercise prompts.
- Smart detection hooks for meeting and Focus Mode awareness.
- Sparkle 2 software update section with manual update checks and release notes.
- Native sleep/wake and screen lock/unlock observers.
- macOS and Windows package identity updates under BreakMate branding.

### Changed

- Rebranded app name and identifiers to BreakMate.
- Updated macOS and Windows metadata, targets, and package identifiers.
- Suppressed intrusive Sparkle update alerts during launch.
- Improved dashboard window behavior after break completion.

### Fixed

- Fixed macOS secondary Flutter engine lifecycle crashes during overlay and companion dismissal.
- Fixed timer drift during sleep, wake, lock, and unlock transitions.
- Fixed dashboard window unexpectedly forcing itself to the front after breaks.

[Unreleased]: https://github.com/bijithintersmart/standup/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/bijithintersmart/standup/releases/tag/v1.3.0
[1.2.1]: https://github.com/bijithintersmart/standup/releases/tag/v1.2.1
[1.2.0]: https://github.com/bijithintersmart/standup/releases/tag/v1.2.0
[1.1.4]: https://github.com/bijithintersmart/standup/releases/tag/v1.1.4
[1.1.3]: https://github.com/bijithintersmart/standup/releases/tag/v1.1.3
[1.1.2]: https://github.com/bijithintersmart/standup/releases/tag/v1.1.2
[1.1.1]: https://github.com/bijithintersmart/standup/releases/tag/v1.1.1
[1.1.0]: https://github.com/bijithintersmart/standup/releases/tag/v1.1.0
[1.0.1]: https://github.com/bijithintersmart/standup/releases/tag/v1.0.1
[1.0.0]: https://github.com/bijithintersmart/standup/releases/tag/v1.0.0
