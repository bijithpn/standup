# Architecture & Responsibilities

## Overview
BreakMate uses a decoupled architecture with specialized isolates and engines for performance.

### 1. Main Dashboard (UI Isolate)
- **Role:** Central hub for settings, statistics viewing, and main timer controls.
- **Components:** `TimerEngine`, `StatsService`, `SettingsRepository`.
- **Note:** Communicates with native code and spawns secondary UI isolates (Break Overlay, Companion).

### 2. Break Overlay
- **Role:** Full-screen intervention to enforce breaks.
- **Responsibilities:**
  - Block background input when in strict mode.
  - Render high-quality templates (breathing, eye sync).
  - Suspend non-critical timers when active.

### 3. Companion Engine (Flame)
- **Role:** Render the interactive pet companion.
- **Responsibilities:**
  - Runs in a separate lightweight engine (`FlutterEngineGroup`).
  - Animates based on IPC events (e.g. `CompanionInteractionEvent`).
  - Throttles rendering when hidden or on battery.

### 4. Background Polling (Isolate)
- **Role:** Continuous tracking without blocking UI.
- **Responsibilities:**
  - Check for idle state, active window class (for meetings/focus).
  - Uses `BackgroundPollingService`.

### 5. Native Bridges
- **Role:** Platform-specific API access (macOS / Windows).
- **Responsibilities:**
  - Menubar / Tray icon management.
  - Notifications.
  - Focus mode and Meeting detection (via OS APIs).
  - IPC with native host.

## Ownership Boundaries
- **`lib/core/`**: Platform integrations, foundational services, utilities, routing.
- **`lib/features/`**: Business behavior, domain models, feature-specific UI (settings, break_overlay, companion).
- **`lib/shared/`**: Visual primitives, reusable widgets, theme colors.
