# BreakMate (standup)

> A macOS menu bar break reminder app for healthy work habits.
>
> **Created by Bijith P N**

BreakMate is a desktop productivity application that reminds you to take regular breaks from computer work. It runs discreetly in your macOS menu bar, providing intelligent break scheduling, smart meeting detection, a desktop cat companion, flash notifications, exercise suggestions, and productivity analytics — all designed to help you maintain healthy work habits.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-macos%20%7C%20windows-lightgrey)
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

---

## Features

### Core
- **Break Timer Engine** — Configurable short/long break intervals with countdown tracking
- **Menu Bar Integration** — System tray with animated cat icons showing real-time countdown
- **Break Profiles** — Pre-configured and custom profiles (Pomodoro, Deep Work, Flexible, Strict)
- **Working Hours** — Timer only runs during configured work days and time ranges
- **Strict Mode** — Prevents skipping breaks; keeps overlay always-on-top
- **Clock Out** — End-of-workday reminder for work-life boundaries

### Smart Detection
- **Meeting Detection** — Auto-pauses during Zoom, Teams, Google Meet, FaceTime calls
- **Focus Mode** — Respects macOS Focus/Do Not Disturb settings
- **Activity Monitoring** — Detects user idle time; auto-pauses and resets timer

### Notifications & Overlays
- **Flash Notifications** — Full-screen flash alerts with customizable:
  - Color schemes (default, photo, cat themes)
  - Animations (pulse, glow, fade, dim, edge)
  - Intensity levels and duration
  - Custom messages
- **Multi-Display Support** — Full-screen overlay across all monitors
- **Break Activities** — Breathing assistant, exercise suggestions, wellness slideshow

### Desktop Companion
- **Animated Cat Pet** — Floating desktop companion using Flame game engine
- **Multiple Themes** — Grey, orange, black, and large cat variants
- **Behavior States** — Idle, blink, stretch, sleeping, alert animations
- **Sprite Sheet Animations** — Smooth frame-by-frame rendering

### Analytics
- **Break Tracking** — Completed, skipped, and total breaks
- **Streaks** — Current and best streak tracking
- **Weekly Heatmap** — Visual representation of break activity
- **Productivity Score** — Computed 0-100 score based on break compliance
- **Insights** — Auto-generated productivity recommendations

### Settings
- **Launch at Startup** — Auto-start on login
- **Single Instance** — Port-based check prevents multiple app instances
- **Appearance** — Dark theme matching macOS native aesthetics
- **Custom Exercises** — CRUD operations for exercise library (eye rest, posture, breathing, movement, stretch)

---

## Architecture

### Pattern: Feature-First + Service Layer with GetIt DI

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│  (Features → Presentation → Widgets/Pages)             │
│         Uses Provider for reactive state                │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                   Application Layer                     │
│  (Controllers: BreakController, StrictModeController)   │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                    Service Layer                        │
│  (TimerEngine, NotificationService, SmartDetection,     │
│   OverlayWindowService, TrayManagerService, etc.)       │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                  Infrastructure Layer                   │
│  (StorageService, MacOSBridge, Native Method Channels)  │
└─────────────────────────────────────────────────────────┘
```

### State Flow

```
SettingsRepository → TimerEngine → BreakController → UI (via Provider)
                        │                    │
                        ▼                    ▼
                   TrayManager         OverlayWindowService
```

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **GetIt DI** | Service locator pattern for singleton services; simple and explicit |
| **Provider** | Reactive state management for UI; ChangeNotifier-based |
| **Multi-Engine** | Three Flutter engines: dashboard, overlay, companion pet — isolated rendering |
| **MethodChannel** | Native macOS bridge for overlay windows, companion window, appearance detection |
| **SharedPreferences** | Lightweight persistent storage for settings (40+ fields) |
| **Feature-First** | Each feature is self-contained with its own models, controllers, and UI |

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
│   │   ├── dependency_injection.dart      # GetIt DI setup (all services registered)
│   │   └── main_layout.dart              # Main window with sidebar navigation
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart        # App-wide constants & storage keys
│   │   ├── errors/
│   │   │   ├── app_exception.dart        # Custom exception class
│   │   │   └── error_handler.dart        # Centralized error handling with guard()
│   │   ├── native/
│   │   │   ├── macos_bridge.dart         # macOS MethodChannel wrapper
│   │   │   ├── meeting_detection_service.dart
│   │   │   └── focus_mode_service.dart
│   │   ├── plugins/
│   │   │   └── windows_overlay_plugin.dart
│   │   ├── services/                     # 14 core services
│   │   │   ├── activity_monitor.dart     # User idle detection
│   │   │   ├── adaptive_break_service.dart
│   │   │   ├── app_navigation_service.dart
│   │   │   ├── flash_controller.dart     # Flash notification state
│   │   │   ├── flash_overlay.dart
│   │   │   ├── flash_service.dart
│   │   │   ├── flash_test_widget.dart
│   │   │   ├── flash.dart
│   │   │   ├── floating_window_service.dart
│   │   │   ├── notification_service.dart # System notifications
│   │   │   ├── overlay_window_service.dart # Multi-monitor overlay management
│   │   │   ├── smart_detection_service.dart # Meeting/focus detection
│   │   │   ├── storage_service.dart      # SharedPreferences wrapper
│   │   │   └── timer_engine.dart         # Core timer logic (~495 lines)
│   │   ├── utils/
│   │   │   ├── logger.dart               # AppLogger service
│   │   │   ├── retry_policy.dart
│   │   │   └── toast.dart
│   │   └── widgets/
│   │       └── app_button.dart
│   │
│   ├── features/                         # 12 feature modules
│   │   ├── analytics/                    # Stats & productivity tracking
│   │   │   ├── stats_model.dart
│   │   │   ├── stats_service.dart
│   │   │   └── presentation/widgets/
│   │   │       ├── productivity_trend_chart.dart
│   │   │       └── stats_chart.dart
│   │   ├── blog/                         # Blog/articles feature
│   │   │   ├── data/
│   │   │   └── presentation/
│   │   ├── break_overlay/                # Break screen overlay
│   │   │   └── presentation/widgets/
│   │   │       └── breathing_assistant.dart
│   │   ├── break_system/                 # Core break functionality (DDD structure)
│   │   │   ├── application/
│   │   │   │   ├── break_controller.dart
│   │   │   │   └── strict_mode_controller.dart
│   │   │   ├── domain/
│   │   │   │   └── break_model.dart
│   │   │   └── presentation/
│   │   │       ├── break_overlay.dart
│   │   │       ├── flash_overlay.dart
│   │   │       ├── pre_break_warning_overlay.dart
│   │   │       ├── standalone_break_overlay.dart
│   │   │       └── widgets/
│   │   │           └── break_activity_graph.dart
│   │   ├── companion/                    # Desktop cat pet companion
│   │   │   ├── controllers/
│   │   │   │   ├── cat_behavior_controller.dart
│   │   │   │   └── companion_overlay_controller.dart
│   │   │   ├── data/
│   │   │   │   └── cat_asset_loader.dart
│   │   │   ├── domain/
│   │   │   │   ├── animation_row_config.dart
│   │   │   │   ├── cat_animation_state.dart
│   │   │   │   └── cat_theme.dart
│   │   │   ├── flame/                    # Flame game engine integration
│   │   │   │   ├── companion_cat_component.dart
│   │   │   │   └── companion_game.dart
│   │   │   ├── overlay/
│   │   │   │   └── companion_overlay_window.dart
│   │   │   └── presentation/
│   │   │       └── companion_dashboard.dart
│   │   ├── flash_overlay/                # Flash notification system
│   │   │   ├── flash_overlay_screen.dart
│   │   │   ├── flash_overlay_service.dart
│   │   │   └── flash_overlay_widget.dart
│   │   ├── menu_bar/                     # System tray/menu bar
│   │   │   ├── menu_bar_popover.dart
│   │   │   └── tray_manager_service.dart # ~498 lines
│   │   ├── notifications/                # (empty — uses core service)
│   │   ├── settings/                     # Settings & configuration
│   │   │   ├── break_profile.dart
│   │   │   ├── exercise_model.dart
│   │   │   ├── settings_model.dart       # 40+ configuration fields
│   │   │   ├── settings_page.dart        # Unified settings UI (~2500+ lines)
│   │   │   └── settings_repository.dart
│   │   ├── themes/                       # (empty)
│   │   ├── tracking/                     # (empty)
│   │   └── wellness/                     # Wellness articles/slideshows
│   │       └── presentation/
│   │           └── wellness_articles_page.dart
│   │
│   └── shared/
│       ├── theme/
│       │   └── app_theme.dart            # Dark theme with macOS styling
│       └── widgets/
│           ├── animated_number.dart
│           ├── countdown_timer.dart
│           ├── pressable_button.dart
│           ├── progress_ring.dart
│           └── staggered_fade_in.dart
│
├── assets/
│   ├── animations/cats/                  # Cat sprite sheets (grey, orange, black, large)
│   ├── fonts/Satoshi/                    # Custom font family
│   ├── icons/                            # Tray icons + cat icons
│   └── slideshow/                        # Wellness slideshow images
│
├── macos/                                # macOS native platform code (Swift/Obj-C)
├── windows/                              # Windows platform code (partial)
├── test/                                 # (empty — no tests yet)
│
├── pubspec.yaml                          # Dependencies & asset declarations
├── analysis_options.yaml                 # Lint configuration
├── devtools_options.yaml                 # DevTools config
└── README.md
```

---

## Key Components

### TimerEngine (`core/services/timer_engine.dart`)

The heart of the application. A state machine that manages:

- **States**: `running`, `paused`, `idle`, `breakActive`
- **Work Modes**: Pomodoro, Deep Work, Flexible, Strict
- **Break Types**: Short breaks (configurable duration), Long breaks (after N short breaks)
- **Activity Monitoring**: Pauses timer when user is idle
- **Event Stream**: Broadcasts state changes to all listeners via `ChangeNotifier`

### OverlayWindowService (`core/services/overlay_window_service.dart`)

Manages system-wide overlay windows:

- Break screen overlay (full-screen, all displays)
- Pre-break warning overlay (countdown warning)
- Flash notification overlay (customizable styles)
- Uses native MethodChannel for macOS window creation

### TrayManagerService (`features/menu_bar/tray_manager_service.dart`)

System tray integration:

- Animated cat icons that change based on app state
- Dynamic tooltip with countdown timer
- Contextual menu (Start/Pause/Skip/Settings/Quit)
- Icon animation states: idle, sleeping (paused), alert (break active)

### SmartDetectionService (`core/services/smart_detection_service.dart`)

Polls every 10 seconds for:

- Running video call apps (Zoom, Teams, Google Meet, FaceTime)
- macOS Focus/Do Not Disturb mode
- Auto-pauses timer during meetings/focus mode

### SettingsRepository (`features/settings/settings_repository.dart`)

Abstracts storage operations:

- Loads/saves `SettingsModel` (40+ fields)
- Uses `StorageService` (SharedPreferences wrapper)
- Repository pattern allows easy migration to other storage backends

### MacOSBridge (`core/native/macos_bridge.dart`)

Native platform channel wrapper:

- Multi-monitor overlay creation
- Companion cat window management
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
| `http` ^1.2.0 | HTTP client |
| `flutter_markdown` ^0.6.18 | Markdown rendering |
| `intl` ^0.19.0 | Date formatting |
| `animations` ^2.0.1 | Animation transitions |
| `flutter_riverpod` ^2.5.1 | Declared but unused |
| `hive_flutter` ^1.1.0 | Declared but unused |

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
#    - runZonedGuarded error handling
#    - flutter_acrylic window initialization
#    - Single instance check (port 10425)
#    - initDependencies() — registers all 16 services
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

### 3. Add Settings (if applicable)

1. Add fields to `SettingsModel` (`features/settings/settings_model.dart`)
2. Update `toMap()` and `fromMap()` methods
3. Add UI in `SettingsPage` (`features/settings/settings_page.dart`)
4. Use `SettingsRepository` to save/load

### 4. Add a New Sidebar Page

1. Create your page in `lib/features/your_feature/presentation/`
2. Add navigation in `MainLayout` (`lib/app/main_layout.dart`)
3. Use `AppNavigationService` for programmatic navigation

### 5. Add Native Functionality (macOS)

1. Define method channel in `MacOSBridge` (`core/native/macos_bridge.dart`)
2. Implement Swift/Objective-C code in `macos/Runner/`
3. Register the method handler in `macos/Runner/AppDelegate.swift`

### 6. Add a New Tray Menu Item

Modify `TrayManagerService` (`features/menu_bar/tray_manager_service.dart`):

```dart
await _trayManager.setContextMenu(Menu(items: [
  // ... existing items ...
  MenuItem(label: 'Your Action'),
]));
```

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
7. **Errors** use `AppException` and `ErrorHandler.guard()`

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

### Planned
- [ ] Windows full support (currently partial)
- [ ] Unit and widget tests
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Auto-update mechanism
- [ ] Custom break sounds
- [ ] Sync settings across devices
- [ ] Widget for macOS Sonoma+
- [ ] Apple Watch companion app
- [ ] **Companion cat drag & mouse interaction** (see Known Issues)
- [ ] **Menu bar click action handlers** (see Known Issues)

### Completed
- [x] Break timer with configurable intervals
- [x] Menu bar integration with animated cat
- [x] Smart meeting detection
- [x] Flash notifications
- [x] Analytics and productivity scoring
- [x] Custom exercise library
- [x] Working hours scheduling
- [x] Strict mode
- [x] Clock out reminders
- [x] Multi-display overlay support

---

## Known Issues

### Companion Cat — Not Draggable / No Mouse Interaction
The desktop cat companion currently renders as a static overlay. It cannot be dragged with the mouse cursor and does not respond to click or hover interactions. The companion window is passive — it displays animations but ignores all mouse events.

**What needs to be implemented:**
- Mouse event passthrough or capture on the companion overlay window
- Drag-and-drop logic to reposition the cat on the desktop
- Click/hover interaction handlers for cat behavior triggers
- Native macOS window level configuration to allow mouse interaction while keeping the window always-on-top

**Files to modify:**
- `lib/features/companion/overlay/companion_overlay_window.dart` — window creation and mouse event handling
- `lib/features/companion/flame/companion_cat_component.dart` — Flame component click/touch detection
- `macos/Runner/` — native window configuration for mouse passthrough or interaction flags

### Menu Bar — Click Actions Not Working
Clicking menu items in the system tray (Start, Pause, Skip, Settings, etc.) produces no visible change. The `TrayManagerService` registers the context menu but the action handlers are not wired to the corresponding service methods.

**What needs to be fixed:**
- Wire `TrayManagerService` menu item callbacks to `TimerEngine` methods (`start()`, `pause()`, `skip()`)
- Connect Settings menu item to `AppNavigationService` to open the settings page
- Ensure `notifyListeners()` is called after state changes so the UI and tray icon update
- Verify the `tray_manager` package event listener is properly subscribed in `init()`

**Files to modify:**
- `lib/features/menu_bar/tray_manager_service.dart` — add `onMenuItemClicked` handler logic
- `lib/app/dependency_injection.dart` — ensure `TrayManagerService` has access to `TimerEngine` and `AppNavigationService`

---

## Troubleshooting

### App doesn't launch
- Check that no other instance is running (port 10425 must be free)
- Run `flutter clean && flutter pub get`

### Overlay doesn't show
- Verify macOS screen recording permissions (System Settings → Privacy & Security)
- Check `MacOSBridge` method channel is properly registered

### Cat companion not visible
- Ensure companion window is enabled in Settings → Companion
- Check macOS accessibility permissions

### Timer doesn't pause during meetings
- Verify Smart Detection is enabled in Settings → Focus Mode
- Check that the meeting app is in the detected list

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

*Built with Flutter and ❤️ for healthy work habits.*
