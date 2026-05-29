# Native Channels

This document outlines all MethodChannels and EventChannels used by BreakMate for IPC between Flutter and native hosts.

## Core Channels

### `com.breakmate.desktop/bridge`
- **Type**: MethodChannel
- **Role**: Primary bidirectional bridge for window management, tray interaction, and settings.
- **Methods**:
  - `showOverlay(map)`: Request the OS to display a full-screen or popup overlay.
  - `hideOverlay()`: Dismiss the active overlay.
  - `setTrayTitle(string)`: Update tray icon text.
  - `setTrayTooltip(string)`: Update tray hover tooltip.
  - `requestPermissions()`: Prompt user for accessibility or notification permissions.

### `com.breakmate.desktop/companion_data`
- **Type**: MethodChannel
- **Role**: Communication specifically for the desktop pet / companion overlay.
- **Methods**:
  - `syncCompanionSettings(map)`: Send settings and state updates to the native window manager to synchronize the companion's behavior and rendering.

### `com.breakmate/events`
- **Type**: EventChannel
- **Role**: Continuous stream from OS to Flutter.
- **Events**:
  - `idle_state_changed`: User presence detection.
  - `focus_mode_changed`: OS focus mode or DND status.
  - `meeting_active`: Video conferencing detection.
