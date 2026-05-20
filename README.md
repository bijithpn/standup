# BreakMate (standup)

> A macOS menu bar break reminder app for healthy work habits.
>
> **Created by Bijith P N**

BreakMate is a desktop productivity application that reminds you to take regular breaks from computer work. It runs discreetly in your macOS menu bar, providing intelligent break scheduling, smart meeting detection, an interactive desktop cat companion, flash notifications, exercise suggestions, and productivity analytics — all designed to help you maintain healthy work habits.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-macos-lightgrey)
![Flutter](https://img.shields.io/badge/Flutter-3.10.4-blue)
![Dart](https://img.shields.io/badge/Dart-3.10.4-blue)

---

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Key Components](#key-components)
- [Dependencies](#dependencies)
- [Getting Started](#getting-started)
- [Building for Production](#building-for-production)
- [Adding New Features](#adding-new-features)
- [Code Conventions](#code-conventions)
- [Roadmap](#roadmap)
- [Technical Debt](#technical-debt)
- [Troubleshooting](#troubleshooting)

---

## Features

### Core Break System
- **Timer Engine** — State machine with running/paused/idle/breakActive states
- **Work Modes** — Pomodoro, Deep Work, Flexible, and Strict profiles
- **Short & Long Breaks** — Configurable intervals (default: 20min short, 60min long)
- **Break Profiles** — Pre-configured and custom profiles with health/productivity presets
- **Working Hours** — Day-of-week selection, start/end time configuration
- **Strict Mode** — Unskippable breaks, screenSaver-level overlay, meeting suppression
- **Clock Out** — End-of-workday reminder for work-life boundaries
- **Break Postponement** — 2-minute postpone option
- **Pre-Break Warning** — 20-second countdown warning before break triggers

### Smart Detection & Automation
- **Meeting Detection** — Auto-pauses during Zoom, Teams, Google Meet, FaceTime, Slack, Webex, Loom (native EventChannel)
- **Focus Mode** — Respects macOS Focus/Do Not Disturb settings (native EventChannel)
- **Activity Monitoring** — Detects user idle time via native bridge; auto-pauses and resets timer
- **Adaptive Break Service** — Learns user activity patterns, suggests optimal intervals, focus quality scoring

### Notifications & Overlays
- **Multi-Display Overlay** — Full-screen break screen across all monitors (separate Flutter engine)
- **Break Overlay** — Ken Burns slideshow, countdown timer, wellness tips, break activity graph
- **Pre-Break Warning** — Countdown warning overlay before break starts
- **Flash Notifications** — Full-screen flash with customizable:
  - Color schemes (default, photo, cat themes)
  - Animations (pulse, glow, fade, dim, edge)
  - Intensity levels and duration
  - Custom messages
- **System Notifications** — Cat-themed attachments, eye rest reminders, posture checks, clock-out reminders

### Desktop Companion (Interactive Pet)
- **Flame Game Engine** — Sprite-based game with low-CPU idle mode (<2% CPU)
- **Cat State Machine (FSM)** — 10 states (idle, blink, stretch, walk, sleep, alert, happy, drag, breakReminder, meetingPaused, focusMode) with 15 event types and timed transitions
- **Event-Driven Behavior** — Companion reacts to all app events (timer changes, breaks, meetings, focus mode, idle) via EventBus
- **4 Cat Themes** — Grey, Orange, Black (composite sprite sheets), Large (separate files)
- **Ambient Behaviors** — Random blink, stretch, look around, yawn, happy animations
- **Draggable Window** — Native `NSPanel` with drag support and interaction handling
- **Click-Through Toggle** — Enable/disable mouse passthrough mode
- **Dynamic Theme/Scale** — Runtime theme switching and scaling without restart

### Tray Menu & Menu Bar
- **MenuBarController** — Centralized action routing for all tray menu items
- **Dynamic Tray Menu** — Contextual menu with real-time timer/break state
- **Animated Cat Icons** — Tray icon changes based on app state (idle, blink, stretch, sleeping, alert)
- **Countdown Tooltip** — Live countdown timer in tray tooltip
- **Display Modes** — Countdown, progress, icon, focusdot display modes

### Analytics & Statistics
- **Break Tracking** — Completed, skipped, and total breaks
- **Streaks** — Current and longest streak tracking
- **Weekly Heatmap** — Visual representation of break activity (365-day rolling)
- **Productivity Score** — Computed 0-100 score based on break compliance
- **Insights** — Auto-generated productivity recommendations
- **Break Activity Graph** — Visual graph shown on break overlay

### Settings & Configuration
- **9 Settings Sections** — General, Breaks & Profiles, Focus Mode, Flash Reminder, Exercises, Clock Out, Companion, Statistics, About
- **40+ Configurable Settings** — All persisted via SharedPreferences
- **Custom Exercise Library** — CRUD for 5 categories (eye rest, posture, breathing, movement, stretch)
- **Launch at Startup** — Auto-start on login
- **Single Instance** — Port-based check (port 10425) prevents multiple app instances

### Wellness
- **Wellness Articles** — 20-20-20 rule, posture, hydration, micro-breaks
- **Wellness Slideshow** — Background images on break overlay with Ken Burns effect
- **Break Activities** — Breathing assistant, exercise suggestions

### Native macOS Integration
- **17 Native Methods** — Overlay show/hide, visual effects, window level, presentation options, idle time, appearance, companion management
- **EventChannel Streams** — Meeting detection and focus mode state streaming
- **Glassmorphic Effects** — flutter_acrylic vibrancy integration
- **`NSPanel` Companion** — Proper floating window with transparency, drag, and always-on-top

---

## Architecture

### Pattern: Feature-First Layered Architecture with Event Bus & Multi-Engine

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│  (Features → Presentation → Widgets/Pages)             │
│         Uses Provider + ChangeNotifier                  │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                   Application Layer                     │
│  (Controllers: BreakController, MenuBarController,      │
│   StrictModeController, CompanionStateManager)          │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                    Event Bus Layer                       │
│  (StreamController pub/sub — 13 typed AppEvent classes) │
│  TimerStateChanged, BreakStarted, MeetingDetected, etc. │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                    Service Layer                        │
│  (TimerEngine, NotificationService, SmartDetection,     │
│   OverlayWindowService, TrayManagerService,             │
│   CompanionBehaviorEngine, WindowService, etc.)         │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                  Infrastructure Layer                   │
│  (StorageService, MacOSBridge, Native Method Channels,  │
│   IPC Bridge, CompanionWindowManager Swift)             │
└─────────────────────────────────────────────────────────┘
```

### State Flow

```
SettingsRepository → TimerEngine → EventBus → Companion FSM → Flame Game
                         │              │
                         ▼              ▼
                   TrayManager    BreakController → OverlayWindowService
```

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **GetIt DI** | Service locator for 20+ singleton services; simple and explicit |
| **Provider** | Reactive UI state via ChangeNotifier (BreakController, TimerEngine) |
| **Event Bus** | Decoupled cross-layer communication — 13 typed event classes, no polling |
| **Multi-Engine** | Three Flutter engines: `main()` dashboard, `overlayMain()` break screen, `companionMain()` desktop pet |
| **FSM Companion** | Cat behavior driven by finite state machine with min-duration guards and event mapping |
| **MethodChannel** | Native macOS bridge for overlays, companion window, idle time, appearance |
| **SharedPreferences** | Lightweight persistent storage for 40+ settings fields |
| **Feature-First** | Each feature is self-contained with domain/application/presentation layers |
| **MenuBarController** | Centralized tray action routing — single source of truth for menu behavior |

---

## Project Structure

```
standup/
├── lib/
│   ├── main.dart                          # Entry point with multi-engine support
│   │                                      # main() → Dashboard
│   │                                      # overlayMain() → Break overlay
│   │                                      # companionMain() → Desktop cat pet
│   │
│   ├── app/
│   │   ├── app.dart                       # BreakMateApp widget (root)
│   │   ├── dependency_injection.dart      # GetIt DI setup (20+ services)
│   │   └── main_layout.dart              # Main window with sidebar navigation
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart        # App-wide constants & storage keys
│   │   ├── errors/
│   │   │   ├── app_exception.dart        # Custom exception class
│   │   │   └── error_handler.dart        # Centralized error handling with guard()
│   │   ├── events/                        # Event bus system
│   │   │   ├── app_events.dart           # 13 typed AppEvent subclasses
│   │   │   ├── event_bus.dart            # StreamController pub/sub singleton
│   │   │   └── events.dart               # Barrel export
│   │   ├── ipc/
│   │   │   └── ipc_bridge.dart           # Inter-process communication
│   │   ├── native/
│   │   │   ├── macos_bridge.dart         # macOS MethodChannel wrapper (17 methods)
│   │   │   ├── meeting_detection_service.dart  # Native EventChannel stream
│   │   │   └── focus_mode_service.dart   # Native EventChannel stream
│   │   ├── services/                      # 15+ core services
│   │   │   ├── activity_monitor.dart     # User idle detection via native bridge
│   │   │   ├── adaptive_break_service.dart # AI-driven break optimization
│   │   │   ├── app_navigation_service.dart # Section-based navigation
│   │   │   ├── flash_service.dart        # Overlay-based flash notifications
│   │   │   ├── notification_service.dart # macOS local notifications
│   │   │   ├── overlay_window_service.dart # Multi-monitor overlay management
│   │   │   ├── smart_detection_service.dart # Meeting/focus polling fallback
│   │   │   ├── storage_service.dart      # SharedPreferences wrapper
│   │   │   ├── timer_engine.dart         # Core timer + EventBus broadcast
│   │   │   └── window_service.dart       # Native macOS window operations
│   │   └── utils/
│   │       ├── logger.dart               # Structured logging
│   │       └── toast.dart                # Success/error toast notifications
│   │
│   ├── features/                          # Feature modules
│   │   ├── analytics/                     # Stats & productivity tracking
│   │   │   ├── stats_model.dart
│   │   │   ├── stats_service.dart
│   │   │   └── presentation/widgets/
│   │   ├── break_system/                  # Core break functionality (DDD)
│   │   │   ├── application/
│   │   │   │   ├── break_controller.dart
│   │   │   │   └── strict_mode_controller.dart
│   │   │   ├── domain/
│   │   │   │   └── break_model.dart
│   │   │   └── presentation/
│   │   │       ├── break_overlay.dart
│   │   │       ├── pre_break_warning_overlay.dart
│   │   │       ├── standalone_break_overlay.dart
│   │   │       └── widgets/
│   │   │           └── break_activity_graph.dart
│   │   ├── companion/                     # Desktop cat pet (FSM-driven)
│   │   │   ├── controllers/
│   │   │   │   └── companion_overlay_controller.dart
│   │   │   ├── data/
│   │   │   │   └── cat_asset_loader.dart  # Sprite sheet loading + caching
│   │   │   ├── domain/
│   │   │   │   ├── cat_state_machine.dart # FSM: 10 states, 15 events
│   │   │   │   ├── cat_animation_state.dart
│   │   │   │   ├── cat_theme.dart         # 4 themes with animation configs
│   │   │   │   └── animation_row_config.dart
│   │   │   ├── flame/
│   │   │   │   ├── companion_game.dart    # Flame game + FSM + low-CPU idle
│   │   │   │   └── companion_cat_component.dart # Sprite + interaction routing
│   │   │   ├── overlay/
│   │   │   │   └── companion_overlay_window.dart # GestureDetector + method channel
│   │   │   └── services/
│   │   │       ├── companion_state_manager.dart   # Event-reactive state
│   │   │       ├── companion_window_controller.dart # Window positioning/opacity
│   │   │       └── companion_behavior_engine.dart # Ambient random behaviors
│   │   ├── menu_bar/                      # System tray/menu bar
│   │   │   ├── controllers/
│   │   │   │   └── menu_bar_controller.dart # Centralized action routing
│   │   │   └── tray_manager_service.dart  # Dynamic menu + animated cat icons
│   │   ├── settings/                      # Settings & configuration
│   │   │   ├── break_profile.dart
│   │   │   ├── exercise_model.dart
│   │   │   ├── settings_model.dart        # 40+ configurable fields
│   │   │   ├── settings_page.dart         # 9-section unified settings UI
│   │   │   └── settings_repository.dart   # SharedPreferences persistence
│   │   └── wellness/                      # Wellness articles/slideshows
│   │       └── presentation/
│   │           └── wellness_articles_page.dart
│   │
│   └── shared/
│       ├── theme/
│       │   └── app_theme.dart            # Dark theme, Satoshi font, glassmorphic
│       └── widgets/
│           ├── animated_number.dart
│           ├── countdown_timer.dart
│           ├── pressable_button.dart
│           ├── progress_ring.dart
│           └── staggered_fade_in.dart
│
├── assets/
│   ├── animations/cats/                   # Grey, orange, black, large sprite sheets
│   ├── fonts/Satoshi/                     # Custom font family
│   ├── icons/                             # Tray icons + cat icons
│   └── slideshow/                         # Wellness slideshow images
│
├── macos/                                 # macOS native platform (Swift)
│   └── Runner/
│       ├── AppDelegate.swift              # 4 method channel registrations
│       ├── CompanionWindowManager.swift   # NSPanel lifecycle, drag, transparency
│       └── Bridges/
│           ├── OverlayWindowBridge.swift  # Strict mode window level
│           ├── MeetingDetectionBridge.swift # Frontmost app detection
│           └── FocusModeBridge.swift      # DND/Focus state
│
├── pubspec.yaml                           # Dependencies & assets
├── analysis_options.yaml                  # Lint configuration
└── README.md
```

---

## Key Components

### TimerEngine (`core/services/timer_engine.dart`)

The heart of the application. A state machine that manages:

- **States**: `running`, `paused`, `idle`, `breakActive`
- **Work Modes**: Pomodoro, Deep Work, Flexible, Strict
- **Break Types**: Short breaks (configurable), Long breaks (after N short breaks)
- **Activity Monitoring**: Pauses timer when user is idle
- **EventBus Broadcast**: Emits `TimerStateChangedEvent`, `BreakStartedEvent`, `BreakCompletedEvent`, etc.

### EventBus (`core/events/event_bus.dart`)

StreamController-based pub/sub system:

- **13 Typed Events**: `TimerStateChangedEvent`, `BreakStartedEvent`, `BreakCompletedEvent`, `MeetingDetectedEvent`, `FocusModeEvent`, `CompanionInteractionEvent`, `TrayActionEvent`, `IdleDetectedEvent`, `ActivityResumedEvent`, `SettingsChangedEvent`, `NavigationEvent`, `NotificationEvent`, `ErrorEvent`
- **Cross-Layer Communication**: Services emit events; consumers (Companion FSM, Tray, Overlay) listen reactively
- **No Polling**: Event-driven architecture eliminates unnecessary CPU usage

### CatStateMachine (`features/companion/domain/cat_state_machine.dart`)

Finite state machine for companion behavior:

- **10 States**: `idle`, `blink`, `stretch`, `walk`, `sleep`, `alert`, `happy`, `drag`, `breakReminder`, `meetingPaused`, `focusMode`
- **15 Events**: `timerTick`, `breakStart`, `breakEnd`, `meetingStart`, `meetingEnd`, `focusStart`, `focusEnd`, `userInteraction`, `idleDetected`, `activityResumed`, `dragStart`, `dragEnd`, `notification`, `celebrate`, `tick`
- **Min-Duration Guards**: Prevents rapid state changes (e.g., blink must last at least 1s)
- **Time-Based Transitions**: `tick` event drives idle-to-sleep transitions after inactivity

### CompanionGame (`features/companion/flame/companion_game.dart`)

Flame game engine integration:

- **FSM Integration**: Maps `CatState` → `CatAnimationState` for sprite rendering
- **Low-CPU Idle Mode**: Frame skipping when cat is in static states (idle, sleep, meetingPaused) to maintain <2% CPU
- **Event Mapping**: Listens to EventBus and routes app events to `CatEvent`s
- **Dynamic Theme**: Runtime theme switching without engine restart

### MenuBarController (`features/menu_bar/controllers/menu_bar_controller.dart`)

Centralized tray action routing:

- **Single Source of Truth**: All tray menu items delegate to this controller
- **Action Types**: Open dashboard/settings/flash/exercises/stats, toggle pause, take break, skip/postpone/complete break, posture reminder, quit
- **Event Emission**: Emits `TrayActionEvent` for cross-component awareness

### OverlayWindowService (`core/services/overlay_window_service.dart`)

Manages system-wide overlay windows:

- **4 Overlay Types**: `breakScreen`, `preBreakWarning`, `flashNotification`, `companion`
- **Multi-Monitor**: Spans all displays via native MethodChannel
- **State-Driven**: Triggered by BreakController based on timer state

### MacOSBridge (`core/native/macos_bridge.dart`)

Native platform channel wrapper (17 methods):

- Overlay show/hide with visual effects
- Window level management (normal, floating, screenSaver)
- Companion show/hide/scale/theme/state/wandering
- System appearance detection (light/dark)
- Idle time detection
- Presentation mode control

---

## Dependencies

### Production

| Package | Purpose |
|---------|---------|
| `macos_ui` ^2.0.9 | Native macOS UI components |
| `tray_manager` ^0.2.3 | System tray integration |
| `window_manager` ^0.5.1 | Window control |
| `flutter_local_notifications` ^18.0.1 | System notifications |
| `launch_at_startup` ^0.3.1 | Auto-launch on login |
| `shared_preferences` ^2.3.4 | Persistent storage |
| `get_it` ^8.0.3 | Dependency injection |
| `provider` ^6.1.2 | State management |
| `screen_retriever` ^0.2.0 | Multi-monitor info |
| `fl_chart` ^0.66.0 | Analytics charts |
| `flame` ^1.37.0 | Game engine (cat companion) |
| `audioplayers` ^6.1.0 | Sound effects |
| `flutter_acrylic` ^1.0.4 | macOS vibrancy effects |
| `intl` ^0.19.0 | Date formatting |
| `flutter_riverpod` ^2.5.1 | Declared but unused |
| `hive_flutter` ^1.1.0 | Declared but unused |
| `http` ^1.2.0 | Declared but unused |
| `flutter_markdown` ^0.6.18 | Declared but unused |
| `animations` ^2.0.1 | Declared but unused |

### Dev Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_test` | Testing framework |
| `flutter_lints` ^6.0.0 | Lint rules |
| `flutter_launcher_icons` ^0.14.4 | App icon generation |

---

## Getting Started

### Prerequisites

- **Flutter SDK** >= 3.10.4
- **Dart SDK** >= 3.10.4
- **macOS** 11.0+ (Big Sur or later)
- **Xcode** 14+ (for macOS build)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd standup

# Install dependencies
flutter pub get

# Run on macOS
flutter run -d macos
```

### Running Specific Engines

```bash
# Dashboard (default)
flutter run -d macos

# The app supports three entry points:
# 1. main()          → Dashboard window
#    - flutter_acrylic window initialization
#    - Single instance check (port 10425)
#    - initDependencies() — registers 20+ services
#    - WindowManager config (1100x750, hidden titlebar)
#    - MethodChannel handler for macOS dock click reopen
# 2. overlayMain()   → Break overlay window (launched programmatically)
#    - StandaloneBreakOverlay widget, @pragma('vm:entry-point')
# 3. companionMain() → Desktop cat pet (launched programmatically)
#    - CompanionOverlayWindow widget, @pragma('vm:entry-point')
```

### Development

```bash
# Watch for file changes
flutter run -d macos --debug

# Run with verbose logging
flutter run -d macos -v

# Check for lint issues
flutter analyze

# Format code
dart format .
```

---

## Building for Production

### macOS

```bash
# Build macOS app
flutter build macos --release

# The built app is located at:
# build/macos/Build/Products/Release/standup.app
```

### Code Signing & Notarization (for distribution)

```bash
# Sign the app
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  --entitlements macos/Runner/Release.entitlements \
  build/macos/Build/Products/Release/standup.app

# Notarize (requires Apple Developer account)
xcrun notarytool submit \
  --keychain-profile "AC_PROFILE" \
  --wait \
  build/macos/Build/Products/Release/standup.zip
```

---

## Adding New Features

### 1. Add a New Feature Module

Follow the feature-first structure:

```
lib/features/your_feature/
├── data/              # Data sources, models, repositories
│   └── your_model.dart
├── domain/            # Business logic entities
│   └── your_entity.dart
├── application/       # Controllers, use cases
│   └── your_controller.dart
└── presentation/      # UI components
    ├── your_page.dart
    └── widgets/
        └── your_widget.dart
```

### 2. Register Services in DI

Add to `lib/app/dependency_injection.dart`:

```dart
final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ... existing registrations ...
  
  // Add your service
  sl.registerLazySingleton<YourService>(() => YourService());
}
```

Services are accessed via `sl<YourService>()` throughout the codebase.

### 3. Add a New Event Type

Add to `lib/core/events/app_events.dart`:

```dart
class YourEvent extends AppEvent {
  final String data;
  YourEvent({required this.data});
  
  @override
  List<Object?> get props => [data];
}
```

Emit via `EventBus.instance.emit(YourEvent(data: 'value'))`.

### 4. Add Settings (if applicable)

1. Add fields to `SettingsModel` (`features/settings/settings_model.dart`)
2. Update `toMap()` and `fromMap()` methods
3. Add UI in `SettingsPage` (`features/settings/settings_page.dart`)
4. Use `SettingsRepository` to save/load

### 5. Add Native Functionality (macOS)

1. Define method in `MacOSBridge` (`core/native/macos_bridge.dart`)
2. Implement Swift code in `macos/Runner/`
3. Register the method handler in `macos/Runner/AppDelegate.swift`

### 6. Add a New Tray Menu Item

Add action to `MenuBarController.handleAction()` and update `TrayManagerService._buildMenu()`.

---

## Code Conventions

### Naming

- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables/Methods**: `camelCase`
- **Constants**: `kPascalCase` (e.g., `kBreakTimerKey`)

### Architecture Rules

1. **Services** live in `core/services/` — singletons registered in GetIt
2. **Features** are self-contained — own models, controllers, UI
3. **Shared widgets** go in `shared/widgets/`
4. **Native code** is abstracted through `MacOSBridge`
5. **Storage** is accessed through `StorageService` or `SettingsRepository`
6. **State** is managed via `Provider` (ChangeNotifier)
7. **Cross-layer communication** uses `EventBus` — no direct service coupling
8. **Errors** use `AppException` and `ErrorHandler.guard()`

### State Management Pattern

```dart
// Service extends ChangeNotifier
class YourService extends ChangeNotifier {
  String _value = '';
  String get value => _value;
  
  void update(String newValue) {
    _value = newValue;
    notifyListeners();
  }
}

// UI consumes via Provider
Consumer<YourService>(
  builder: (context, service, child) {
    return Text(service.value);
  },
)
```

---

## Roadmap

### High Priority
- [ ] **Wire CompanionStateManager.startListening()** — Registered in DI but never activated; the entire event-reactive companion system is inactive
- [ ] **Implement IpcBridge.setEventHandler()** — IPC system fully built but never wired up for cross-engine messaging
- [ ] **Connect AdaptiveBreakService.recordWorkSession()** — Adaptive learning system collects no data; never called anywhere
- [ ] **Implement TimerEngine.saveState()** — Empty method; timer state persistence is a no-op
- [ ] **Register WindowService MethodChannel** — Uses `com.breakmate/window` channel not registered in `AppDelegate.swift`; all 11 operations silently fail
- [ ] **Remove unused dependencies** — `flutter_riverpod`, `hive_flutter`, `http`, `flutter_markdown`, `animations` declared but never imported

### Medium Priority
- [ ] **Split monolithic settings_page.dart** — 2200+ lines in one file; should be split into section widgets
- [ ] **Implement Focus Mode settings** — DND toggle, daily goal, session length have empty `onChanged` handlers
- [ ] **Implement Notification settings** — Repeated alerts, dock bounce toggles non-functional
- [ ] **Custom wallpaper file picker** — Saves literal string `'default_path'` instead of actual file
- [ ] **About page navigation** — Website, Privacy, Terms cards have no `onTap` handlers
- [ ] **Implement CompanionStateManager._idleTimer** — Field declared but never used
- [ ] **Add polling fallback to MeetingDetectionService** — EventChannel only; silently fails if native bridge unavailable
- [ ] **Add polling fallback to FocusModeService** — Same issue as meeting detection
- [ ] **Implement CompanionBehaviorEngine._triggerBlink()** — Only logs, does not emit event
- [ ] **Fix StandaloneBreakOverlay hardcoded graph data** — Uses `[2, 4, 3, 6, 5, 8, 7]` with comment acknowledging "Real stats not easily accessible"

### Low Priority / Future Features
- [ ] **Blog feature** — Complete scaffold exists (`lib/features/blog/`) with no implementation
- [ ] **Tracking feature** — Empty directory, no implementation
- [ ] **Windows full support** — Platform code exists but incomplete
- [ ] **Unit and widget tests** — No test coverage
- [ ] **CI/CD pipeline** — GitHub Actions for build/test/release
- [ ] **Auto-update mechanism** — Sparkle or similar for macOS
- [ ] **Custom break sounds** — User-selectable audio notifications
- [ ] **Sync settings across devices** — Cloud backup/sync
- [ ] **macOS Sonoma+ widget** — Desktop widget for break status
- [ ] **Apple Watch companion app** — Remote break control and notifications
- [ ] **Export statistics** — CSV/PDF export of break history
- [ ] **Keyboard shortcuts** — Global hotkeys for pause/skip/take break
- [ ] **Break activity suggestions** — AI-powered personalized break activities
- [ ] **Team/enterprise mode** — Shared break schedules, admin dashboard
- [ ] **Integration with calendar apps** — Auto-detect meetings from Calendar.app
- [ ] **HealthKit integration** — Sync break data with Apple Health
- [ ] **Multi-language support** — i18n for non-English users

### Completed
- [x] Break timer with configurable intervals and work modes
- [x] Menu bar integration with animated cat icons
- [x] Smart meeting detection (native EventChannel)
- [x] Focus Mode / DND detection (native EventChannel)
- [x] Flash notifications with customizable styles
- [x] Analytics and productivity scoring with heatmap
- [x] Custom exercise library (5 categories)
- [x] Working hours scheduling
- [x] Strict mode with unskippable breaks
- [x] Clock out reminders
- [x] Multi-display overlay support
- [x] Desktop companion with Flame game engine
- [x] Cat state machine (FSM) with 10 states
- [x] Event bus for cross-layer communication
- [x] Centralized menu bar controller
- [x] Draggable companion window (NSPanel)
- [x] Low-CPU idle mode (<2% CPU)
- [x] Dynamic theme switching and scaling
- [x] Single instance enforcement
- [x] Pre-break warning overlay
- [x] Adaptive break service (scaffolded)
- [x] Wellness articles and slideshow

---

## Technical Debt

### Critical
1. **Unregistered MethodChannel** — `WindowService` uses `com.breakmate/window` which is never registered in `AppDelegate.swift`. All 11 window operations throw `MissingPluginException` silently.
2. **Dead Code: CompanionStateManager** — Registered in DI but `startListening()` never called. The event-reactive companion state system is completely inactive.
3. **Dead Code: IpcBridge** — Fully implemented but `setEventHandler()` never invoked. Cross-engine IPC is non-functional.
4. **AdaptiveBreakService receives no data** — `recordWorkSession()` is never called. The adaptive learning system cannot function.
5. **TimerEngine.saveState() is a no-op** — Empty method body. Timer state is never persisted across restarts.

### Moderate
6. **Duplicate overlay systems** — `BreakOverlay` (in-app) and `StandaloneBreakOverlay` (separate engine) have nearly identical UI code.
7. **Settings page is monolithic** — `settings_page.dart` is 2200+ lines; should be split into section widgets.
8. **Empty `onChanged` handlers** — Focus mode DND toggle, repeated alerts, dock bounce — all non-functional.
9. **No polling fallback** — `MeetingDetectionService` and `FocusModeService` rely solely on EventChannel; no graceful degradation.
10. **Cat animation frame extraction** — Writes to `/tmp/` without cleanup; potential disk accumulation.

### Minor
11. **5 unused dependencies** — `flutter_riverpod`, `hive_flutter`, `http`, `flutter_markdown`, `animations` in pubspec.yaml but never imported.
12. **No test coverage** — `test/` directory exists but no meaningful tests.
13. **Windows platform code** — Exists but incomplete; may cause confusion.
14. **`fix_timer.py`** — Unknown purpose script in `macos/Runner/`.

---

## Recent Changes

| Date | Change |
|------|--------|
| May 2026 | **Refactor companion architecture** — FSM-driven cat behavior, EventBus integration, low-CPU idle mode |
| May 2026 | **Implement MenuBarController** — Centralized tray action routing |
| May 2026 | **Refactor TrayManagerService** — Delegates to MenuBarController, instant sync with TimerEngine |
| May 2026 | **Fix native macOS companion window** — Proper `NSPanel` lifecycle, drag support, transparency |
| May 2026 | **Update dependency injection** — Wire all new services, remove dead code |
| May 2026 | **Clean up dead files** — Remove `cat_behavior_controller.dart`, `companion_dashboard.dart`, unused barrel |
| May 2026 | **Fix Swift build error** — Remove invalid `acceptsFirstMouse` override |
| Earlier | Desktop companion pet with animated sprite support |
| Earlier | Native macOS integration (focus mode, meeting detection, strict mode overlays) |
| Earlier | Settings UI redesign with Satoshi font, unified theme, sidebar navigation |
| Earlier | Multi-monitor overlay with standalone Flutter engine |
| Earlier | Single-instance socket messaging |
| Earlier | Pre-break warning system |

---

## Troubleshooting

### App doesn't launch
- Check that no other instance is running (port 10425 must be free)
- Run `flutter clean && flutter pub get`

### Overlay doesn't show
- Verify macOS screen recording permissions (System Settings → Privacy & Security)
- Check `MacOSBridge` method channel is properly registered in `AppDelegate.swift`

### Cat companion not visible
- Ensure companion window is enabled in Settings → Companion
- Check macOS accessibility permissions

### Timer doesn't pause during meetings
- Verify Smart Detection is enabled in Settings → Focus Mode
- Check that the meeting app is in the detected list (Zoom, Teams, Meet, FaceTime, Slack, Webex, Loom)

### Tray menu actions not working
- Check that `MenuBarController` is properly wired in `dependency_injection.dart`
- Verify `TrayManagerService.setMenuBarController()` is called

### Build fails with Swift errors
- `CompanionWindowManager.swift` may show "No such module 'FlutterMacOS'" — this is an LSP artifact and does not affect builds
- Run `flutter clean && flutter build macos --debug` to verify

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

*Built with Flutter and ❤️ for healthy work habits.*
