# BreakMate

> A high-performance, multi-engine macOS & Windows productivity suite designed to protect your physical and mental well-being.
>
> **Developed by Bijith P N**

BreakMate is a sophisticated wellness platform that integrates deeply with your desktop environment. By utilizing multiple Flutter engines, a custom behavior AI for ambient feedback, and native platform hooks, BreakMate ensures that your work-life balance is actively managed without disrupting your creative flow.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-macos%20|%20windows-lightgrey)
![Flutter](https://img.shields.io/badge/Flutter-3.10.4-blue)

---

## 🎯 Scope & Purpose

Modern computing often leads to "flow-state tunnel vision," where users ignore the physical costs of prolonged sitting and screen time. BreakMate's scope is to bridge the gap between intent and action. It provides:
1. **Physical Protection**: Through enforced eye-rest, stretching, and movement prompts.
2. **Mental Clarity**: By utilizing Pomodoro and Deep Work cycles to prevent cognitive fatigue.
3. **Ambient Awareness**: Using a non-intrusive desktop pet to reflect app state and encourage a more relaxed workspace.

---

## ✨ Features in Depth

### 🕒 Intelligent Break Orchestration
- **The Engine**: A high-precision `TimerEngine` manages the transition between states. It calculates focus quality based on how often you skip or postpone breaks.
- **Strict Mode**: When enabled, the app uses a `screenSaver` window level on macOS and a top-most overlay on Windows, effectively locking the workstation for the duration of the break.
- **Pre-Break Warning**: A translucent 20-second countdown overlay appears before breaks, allowing you to gracefully finish your last sentence or commit your code.

### 🧠 Smart Detection (The "Silent" Feature)
- **Zero-Touch Pausing**: Using native EventChannels, the app detects if you are in a meeting (Zoom, Teams, etc.) and auto-pauses the timer. It resumes only when the call ends.
- **Idle Intelligence**: If you walk away from your desk for more than 5 minutes, BreakMate detects the inactivity via the native bridge and automatically resets or pauses the work cycle.

### 🐈 Pet Behavior Engine (The AI Brain)
The desktop pet (cat/dog) isn't just a static animation; it's driven by `PetBehaviorBrain`, an AI decision engine:
- **Weighted Decision Making**: Uses a weighted scoring algorithm to choose the next behavior based on context.
- **Context Awareness**: If the cursor is nearby, the pet enters an `interacting` or `curious` state. If a meeting is detected, it enters a `quiet` or `sleep` state.
- **Personality Matrix**: Each pet profile has unique traits like `playfulness`, `curiosity`, and `sociability`.
- **Recency Penalty**: Prevents the pet from repeating the same animation twice in a row, making it feel more "alive."

### 📈 Analytics & Wellness Insights
- **Heatmaps**: A GitHub-style activity graph tracking your focus consistency over a 365-day window.
- **Productivity Score**: A proprietary algorithm that weights completed breaks vs. skipped ones against your daily goal.
- **Wellness Library**: A curated collection of articles and exercises designed by ergonomic experts.

---

## 🎨 UI & UX Design Philosophy

BreakMate uses a **Glassmorphic / Neo-Native** design language.
- **Vibrancy & Blur**: Leveraging `macos_ui` and `flutter_acrylic` to create translucent sidebars and windows that blend perfectly with the host OS.
- **Staggered Animations**: Every page transition and widget entry uses `StaggeredFadeIn` for a premium, fluid feel.
- **Satoshi Typography**: A custom geometric sans-serif font family used app-wide.
- **Interactive Feedback**: Custom `PressableButton` and `ProgressRing` widgets provide tactile visual feedback.

---

## 🏗️ Technical Architecture

### Multi-Engine Strategy
The app is split into three distinct Flutter instances to maximize performance:
1. **Main App**: Handles tray management, settings, and the dashboard.
2. **Overlay Engine**: A dedicated high-priority engine for full-screen break screens.
3. **Companion Engine**: A low-overhead Flame-based engine for the desktop pet.

### 🧬 State Management & Communication
- **Provider**: Used for local UI state and reactive updates in the dashboard.
- **EventBus**: A centralized hub for app-wide events (`MeetingDetected`, `TimerTick`, `PetInteracted`).
- **CompanionStateManager**: Listens to the EventBus and maintains the Finite State Machine (FSM) for the pet, transitioning between `idle`, `sleeping`, `alert`, and `happy` states based on system events.
- **IPC Bridge**: A custom `MethodChannel` layer (`com.breakmate/ipc`) that synchronizes state across the three separate isolates. It ensures the Companion knows the Timer's state and the Overlay knows when a meeting starts.

### 💾 Storage & Persistence Architecture
To ensure maximum reliability, BreakMate employs a multi-layered storage strategy:
1. **ObjectBox (Primary)**: A high-performance NoSQL database used for complex objects like `SettingsSnapshot`, `DailyStats`, and `CompanionPreferences`.
2. **Key-Value Mirror (Resilience)**: Critical flags (like onboarding completion) are mirrored to a stable primitive `KeyValueRecord` table. This acts as a "source of truth" if complex snapshots fail to decode.
3. **Automatic Migration**: On macOS, the database was moved from `~/Documents` to `~/Library/Application Support` for better stability. The app automatically detects legacy data and migrates it to the new location on first launch.
4. **Isolate Safety**: Storage initialization is restricted to the main isolate to prevent database locking issues across multiple engines.

---

## 🔌 Plugin & Dependency Directory

| Plugin | Usage in BreakMate |
|--------|-------------------|
| `macos_ui` | Provides the native look-and-feel for the macOS dashboard. |
| `flutter_acrylic` | Enables the translucent (vibrancy/acrylic) window effects. |
| `tray_manager` | Powers the animated tray icon and the dynamic context menu. |
| `window_manager` | Handles complex window operations like "always on top" and custom resizing. |
| `flame` | The 2D game engine powering the desktop pet animations. |
| `audioplayers` | Manages lofi background music and notification sound effects. |
| `fl_chart` | Renders the complex productivity heatmaps and trend lines. |
| `shared_preferences` | Persists over 40+ user settings and break history. |
| `get_it` | The service locator used for clean dependency injection. |
| `launch_at_startup` | Registers the app with the OS to start automatically on login. |
| `screen_retriever` | Detects multi-monitor setups to ensure overlays span all screens. |
| `flutter_local_notifications` | Sends system-level reminders for posture and hydration. |
| `intl` | Handles complex date/time formatting for analytics and history. |
| `url_launcher` | Handles external links for wellness articles and documentation. |
| `path_provider` | Locates platform-specific directories for caching and data storage. |

---

## 📂 Deep Dive: Project Structure

### `lib/app/`
- `dependency_injection.dart`: The "Wiring Diagram" of the app where all services are instantiated.
- `main_layout.dart`: The sidebar navigation logic and master layout.

### `lib/core/`
- `native/macos_bridge.dart`: The "Control Center" for 20+ native calls (Overlay, Companion, Idle Time).
- `services/timer_engine.dart`: The core logic that runs the work/break cycles.
- `ipc/ipc_bridge.dart`: The underlying mechanism for inter-isolate communication.
- `events/app_events.dart`: Definitions for every possible system message.

### `lib/features/companion/`
- `ai/pet_behavior_brain.dart`: The intelligence engine described above.
- `flame/companion_game.dart`: The rendering loop for pet animations.
- `services/companion_state_manager.dart`: Reactively maps app events to pet behaviors.

### `lib/features/settings/`
- `settings_page.dart`: A unified control panel for every app parameter.
- `settings_model.dart`: The data schema for app configuration.

---

## 🖥️ Platform Bridges

### macOS (Swift)
- **`AppDelegate.swift`**: Handles `FlutterEngineGroup` management and MethodChannel routing.
- **`CompanionWindowManager.swift`**: Creates a custom `NSPanel` for the draggable pet.

### Windows (C++)
- **`display_bridge.cpp`**: Low-level Win32 calls to manage multi-monitor overlay placement.
- **`companion_window_manager.cpp`**: Implements layered windows for pet animations.

---

## 🗺️ Roadmap
- [x] **Desktop Companion**: Draggable pet with basic behavior.
- [ ] **Flash Notifications**: Subtle screen-edge pulse cues (Development paused).
- [ ] **Adaptive AI**: Pet will learn your work habits and warn you *before* you get tired.
- [ ] **Mobile Sync**: An iOS/Android companion app for notifications.

---

## 📜 License
MIT License - See the `LICENSE` file for details.

---
*Built with Flutter by Bijith P N*
