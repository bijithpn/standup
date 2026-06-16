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

## IPC State Event Payload Specifications (Dart 3 Sealed Classes)

Cross-engine and cross-isolate state synchronizations are modeled using the Dart 3 `sealed class` hierarchy `IpcEvent` in [ipc_events.dart](file:///Users/intersamrt/Documents/Flutter-Projects/standup/lib/core/ipc/ipc_events.dart).

Every IPC event shares the following base JSON wrapper shape:

```json
{
  "eventName": "string",
  "version": 1,
  "payload": {}
}
```

The table below lists all `IpcEvent` subtypes, their event names, and their corresponding JSON payload specifications:

| Event Name (`eventName`) | Class Type | Payload Key / Type | Description |
| :--- | :--- | :--- | :--- |
| **`timer.stateChanged`** | `TimerStateChangedIpcEvent` | `state` (String)<br>`countdownSeconds` (int)<br>`workElapsedSeconds` (int)<br>`targetEndTime` (int?)<br>`totalWorkTodaySeconds` (int?) | Dispatched when the main countdown state or session changes. |
| **`timer.breakStarted`** | `BreakStartedIpcEvent` | `isLongBreak` (bool)<br>`durationSeconds` (int)<br>`title` (String) | Triggered when a break window begins. |
| **`timer.breakEnded`** | `BreakEndedIpcEvent` | `skipped` (bool) | Dispatched when a break window concludes or is skipped. |
| **`companion.interaction`** | `CompanionInteractionIpcEvent` | `interactionType` (String)<br>`metadata` (Map?) | Triggered by user interaction events with the companion pet. |
| **`detection.meeting`** | `MeetingDetectedIpcEvent` | `isActive` (bool)<br>`bundleId` (String) | Relayed when a meeting app launch is detected. |
| **`detection.focusMode`** | `FocusModeIpcEvent` | `isActive` (bool) | Relayed when OS-level Focus Mode / DND state changes. |
| **`tray.action`** | `TrayActionIpcEvent` | `action` (String) | Actions triggered from the system tray menu. |
| **`companion.close`** | `CompanionCloseIpcEvent` | *None* | Commands the companion engine to close. |
| **`companion.positionChanged`**| `CompanionPositionChangedIpcEvent`| `x` (double)<br>`y` (double) | Dispatched when the companion window coordinates shift. |
| **`companion.stateChanged`** | `CompanionStateChangedIpcEvent` | `state` (String) | Updates the mood or state of the companion pet (e.g. idle, alert). |
