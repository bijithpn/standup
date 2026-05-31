# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-05-31

### Added
- **Contextual Wellness Engine**: Intelligent break suggestions based on current application activity (Coding, Writing, Browsing, etc.).
- **App-Specific Behavior**: Native bridge for macOS to track frontmost application for contextual tips.
- **Calendar Integration**: Added `device_calendar_plus` support to automatically delay breaks when a meeting is imminent.
- **Personal Goals**: New settings section to set daily focus hours, break count targets, and sitting limits.
- **Smart End-of-Day Wind-Down**: Automatic trigger of a "Wind-down" session at clock-out time with a daily productivity summary.
- **Wellness Library**: Management page for exercises allowing users to favorite, hide, and rotate activities.
- **Companion Progression**: Unlocking system for pets based on "Consistency Days" (days with at least one completed break).
- **Privacy Report**: New settings section detailing local data storage and native permissions for transparency.

### Changed
- Migrated from `device_calendar` to `device_calendar_plus` to resolve dependency version conflicts.
- Updated `BreakOverlay` to support the new `WindDownTemplate`.
- Enhanced `AdaptiveBreakService` with contextual awareness.
- Redesigned main layout navigation to include Personal Goals and Wellness Library.
- Improved companion theme persistence to use neutral "pet" naming conventions.

### Fixed
- Resolved `timezone` package version conflict through dependency overrides.
- Fixed various Dart analysis issues related to method vs class usage in settings widgets.
- Corrected streak logic to ensure a day is only counted once towards consistency metrics.
- Updated deprecated `withOpacity` calls to modern `withValues`.
- Cleaned up unused imports and improved type safety in core services.

## [1.1.4] - 2026-05-29

### Added
- **ObjectBox Persistence**: Full integration of ObjectBox for high-performance local storage of settings, stats, and preferences.
- **New Storage Models**: Implemented schemas for companion preferences, daily stats, and settings snapshots.
- **UI Refinement**: Updated accent colors and polished the modern Zinc/Slate design system.
- **Release Documentation**: Added comprehensive release build and maintenance documentation.

### Fixed
- **Onboarding Persistence**: Resolved issues with onboarding state not persisting correctly.
- **Storage Stability**: Migrated app data to proper Application Support directories on macOS to avoid database lock issues.

## [1.1.3] - 2026-05-25

### Added
- **Custom Wallpapers**: Support for custom background images in companion preview and settings.
- **Enhanced Snooze**: Added flexible snooze options and durations to the tray menu and dashboard.
- **File Picker**: Integrated `file_picker` for selecting custom assets.
- **Installer Improvements**: Updated DMG installer layout and branding for macOS.

### Changed
- **Isolate Management**: Improved identification and lifecycle management of secondary isolates (Overlays, Companion).
- **Companion Settings**: Overhauled pet picker with real-time preview and background selection.
- **Tray Optimization**: Refactored tray manager initialization to improve startup speed.

## [1.1.2] - 2026-05-15

### Changed
- **Roadmap Update**: Updated project metrics and performance targets based on codebase analysis.
- **Dependency Audit**: Cleaned up unused packages and updated build maintenance scripts.

## [1.1.0] - 2026-05-10

### Added
- **Priority 5 UX Overhaul**: Implementation of the new Zinc/Slate design system across the entire application.
- **Today Dashboard**: A new action-oriented dashboard featuring focus timers, smart recommendations, and quick actions.
- **Integrated Onboarding**: Interactive first-run flow to guide users through initial configuration.
- **Intelligent Recommendations**: Added behavior logic to suggest relevant activities based on usage patterns.
- **Flame Companion**: Introduced the animated pet system powered by the Flame game engine.
- **Native Bridges**: Implemented cross-platform bridges for meeting detection, focus mode (macOS), and window management.
- **IPC Infrastructure**: Created a typed IPC bridge for robust communication between app windows.

### Fixed
- **Timer Accuracy**: Resolved drift issues on macOS during system sleep and wake cycles.
- **Single Instance Logic**: Improved prevention of multiple app instances running simultaneously.

## [1.0.0] - 2026-05-01

### Added
- Initial release of BreakMate.
- Core break reminder system with short and long break intervals.
- Basic break overlays with countdowns.
- System tray integration for macOS and Windows.
- Initial analytics dashboard and focus time tracking.
- Exercise widgets for breathing and eye rest.
- Auto-update support via Sparkle (macOS).
