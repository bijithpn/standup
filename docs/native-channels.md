# Native Channels

This document outlines all MethodChannels and EventChannels used by BreakMate for IPC between Flutter and native hosts.

## Core Channels

### `com.breakmate/bridge`
- **Type**: MethodChannel
- **Role**: Primary bidirectional bridge for window management, tray interaction, and settings.
- **Methods**:
  - `showOverlay(map)`: Request the OS to display a full-screen or popup overlay.
  - `hideOverlay()`: Dismiss the active overlay.
  - `setTrayTitle(string)`: Update tray icon text.
  - `setTrayTooltip(string)`: Update tray hover tooltip.
  - `requestPermissions()`: Prompt user for accessibility or notification permissions.

### `com.breakmate/events`
- **Type**: EventChannel
- **Role**: Continuous stream from OS to Flutter.
- **Events**:
  - `idle_state_changed`: User presence detection.
  - `focus_mode_changed`: OS focus mode or DND status.
  - `meeting_active`: Video conferencing detection.

## Future Unification
Currently some Windows code may use `com.breakmate.macos/bridge` internally; this is being transitioned to the neutral `com.breakmate/bridge` prefix to avoid confusion across platforms.
