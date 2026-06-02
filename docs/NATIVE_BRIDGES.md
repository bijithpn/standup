# Native Bridges

Authoritative contract for the Flutter ↔ native (macOS / Windows) surface
in BreakMate. This document extends `native-channels.md` with the full
method inventory, event dispatch table, and the rule for which surface
to call from Dart.

If you are adding a new native capability, the contract definition lives
here first. Update this file in the same change that touches the
channel handler.

## Surfaces

| Surface | Type | Lives in | Used by |
| --- | --- | --- | --- |
| `NativeBridgePlatform` | Dart abstract | `core/native/native_bridge.dart` | Platform-specific bridges (`MacOSBridge`, `WindowsBridge`) |
| `NativeBridgeFacade` | Dart abstract | `core/native/native_bridge_facade.dart` | High-level call sites (recommended) |
| `NativeBridgeFallback` | Dart stub | `core/native/native_bridge_fallback.dart` | Tests, headless mode |
| `FallbackBridge` | Dart concrete | `core/native/native_bridge.dart` | Real fallback path when a method is missing on the current platform |

Use the facade from app code. Use `NativeBridgePlatform` only from the
platform bridges themselves or when the facade does not yet cover a
method. Use the fallback only in tests.

## Channel inventory

| Channel | Type | Used by |
| --- | --- | --- |
| `com.breakmate.desktop/bridge` | MethodChannel | Overlay, window, companion, calendar |
| `com.breakmate/focus_mode` | EventChannel | DND / focus mode stream |
| `com.breakmate/meeting_detection` | EventChannel | Frontmost meeting app detection |
| `com.breakmate/app_tracking` | MethodChannel | Active app queries |
| `com.breakmate.desktop/companion_data` | MethodChannel | `syncCompanionSettings(map)` |
| `com.breakmate/events` | EventChannel | `idle_state_changed`, `focus_mode_changed`, `meeting_active` |
| `tray_manager` (plugin) | MethodChannel / EventChannel | `tray_manager_service.dart` |

## NativeBridgePlatform (23 methods)

The full contract that every platform bridge must satisfy. Methods are
grouped by responsibility.

### Overlay

| Method | Args | Returns |
| --- | --- | --- |
| `showOverlay([Map? args])` | optional overlay payload | `bool` |
| `hideOverlay({bool restoreMainWindow = true})` | `{}` | `void` |
| `skipBreak()` | — | `void` |
| `setVisualEffect(String material)` | material name | `void` |
| `focusApp()` | — | `void` |
| `setWindowLevel(int level)` | macOS window level | `void` |
| `setPresentationOptions({bool? hideDock, bool? hideMenu})` | options | `void` |
| `setIgnoreMouseEvents(bool ignore)` | `bool` | `void` |
| `updateOverlayData(Map data)` | partial overlay payload | `void` |

### System

| Method | Args | Returns |
| --- | --- | --- |
| `getIdleTime()` | — | `int` seconds |
| `getAppearance()` | — | `String` (`light` / `dark` / `system`) |

### Companion

| Method | Args | Returns |
| --- | --- | --- |
| `showCompanion(Map args)` | position, scale, theme | `void` |
| `hideCompanion()` | — | `void` |
| `setCompanionClickThrough(bool ignore)` | `bool` | `void` |
| `updateCompanionScale(double scale)` | `double` | `void` |
| `updateCompanionTheme(String themeId)` | theme id | `void` |
| `updateCompanionName(String petName)` | display name | `void` |
| `triggerCompanionState(String stateName)` | `CatAnimationState` name | `void` |
| `setCompanionWandering(bool enabled)` | `bool` | `void` |
| `setCompanionFollowMouse(bool enabled)` | `bool` | `void` |

### Calendar

| Method | Args | Returns |
| --- | --- | --- |
| `requestCalendarPermissions()` | — | `bool` granted |
| `hasCalendarPermissions()` | — | `bool` |
| `openCalendarSettings()` | — | `void` |
| `getUpcomingCalendarEvents(int windowMinutes)` | minutes ahead | `List<Map>` |

`MacOSBridge` wraps every MethodChannel call in `_invokeSafely`, which
swallows `MissingPluginException` once per method (deduped via
`_loggedMissingMethods`) so a single unimplemented method does not
flood the log on every tick.

`WindowsBridge` provides no-op fallbacks with `developer.log` for
`skipBreak`, `setVisualEffect`, and `setPresentationOptions`. Other
methods have parity with macOS.

## NativeBridgeFacade (6 high-level methods)

The recommended call site. Wraps `NativeBridgePlatform` for common app
flows.

| Method | Purpose |
| --- | --- |
| `requestPermissions()` | Triggers all platform permission prompts and returns a `NativePermissionStatus` |
| `showOverlay(Map data)` | Convenience over `NativeBridgePlatform.showOverlay` with typed payload |
| `hideOverlay()` | Convenience over `hideOverlay(restoreMainWindow: true)` |
| `setTrayTitle(String title)` | Forwards to the active platform bridge |
| `setTrayTooltip(String tooltip)` | Forwards to the active platform bridge |
| `checkCapabilities()` | Returns which optional capabilities are available on this platform |

`NativePermissionStatus` is a 4-bool model: `isMeetingDetectionAvailable`,
`isFocusModeAvailable`, `isNotificationsAllowed`, `isLaunchAtStartupEnabled`.
It has `copyWith`.

## NativeBridgeFallback

A 10-line stub used by tests and headless mode. It exposes:

- `handleFailure(String method, Object error)` — logs and surfaces
  missing permissions into settings state.
- `isAvailable(String method)` — currently always returns `true`.

`FallbackBridge` (in `core/native/native_bridge.dart`) is the real
fallback path: when a platform bridge throws `MissingPluginException`,
the orchestrator routes the call into `FallbackBridge` instead of
failing the whole flow. `NativeBridgeFallback` is what test code
substitutes for the platform bridge.

## Event dispatch (Dart side)

`dependency_injection.dart::_setupIpcBridge` registers a single
`IpcBridge.setEventHandler` callback. The native side calls
`ipc.send(event, data)`; the Dart side dispatches by `event` name.

| Event | Dart action |
| --- | --- |
| `timerStateChanged` | Map state string to `TimerStateEvent`, emit `TimerStateChangedEvent` |
| `breakStarted` | Emit `BreakStartedEvent(isLongBreak, durationSeconds, title)` |
| `breakEnded` | Emit `BreakEndedEvent(skipped)` |
| `detection.meeting` | Emit `MeetingDetectedEvent(isActive, bundleId)` |
| `detection.focusMode` | Emit `FocusModeEvent(isActive)` |
| `tray.action` | Map `action` (`start` / `pause` / `reset`) to `TimerEngine` calls |
| `companion.positionChanged` | Emit `CompanionPositionChangedEvent(x, y)` |
| `companion.stateChanged` | Map `data['state']` string to `CompanionState` enum |
| `companionInteraction` | Forward to companion behavior engine |

Native events must always be JSON-serializable: `String`, `int`, `bool`,
`double`, `null`, or `Map` / `List` of those. Anything else is a bug.

## Method handlers (Flutter side)

`main_common.dart` registers two `MethodChannel` handlers:

| Channel | Method | Dart action |
| --- | --- | --- |
| `com.breakmate.desktop/bridge` | `handleReopen` | `OverlayWindowService.showDashboard(forceShow: true)` |
| `com.breakmate.desktop/bridge` | `skipBreak` | `BreakController.skipCurrentBreak()` |
| `com.breakmate.desktop/bridge` | `systemSleep` | `TimerEngine.handleSystemSleep()` |
| `com.breakmate.desktop/bridge` | `systemWake` | `TimerEngine.handleSystemWake()` |

It also wires a `singleInstanceServer` for single-instance behavior:

| Event | Action |
| --- | --- |
| `shutdown` | `_gracefulShutdown(singleInstanceServer)` |
| `showDashboard` | `OverlayWindowService.showDashboard(forceShow: true)` |

And a launch-at-startup hook that resolves the executable via
`PackageInfo.fromPlatform().appName` + `Platform.resolvedExecutable`.

## Versioning

There is no version negotiation today. Every `MethodCall` from native
to Dart is assumed to be understood. Before the next breaking change
to the bridge, add:

1. A `protocolVersion` getter on each `NativeBridgePlatform`
   implementation. macOS and Windows should return the same number when
   the contract is identical.
2. A `version` field on every Dart-side `MethodCall` invocation, set
   from a single `const bridgeProtocolVersion = 1` constant.
3. A startup check in `main_common.dart` that fails fast with a
   structured error if `bridgeProtocolVersion` does not match the
   native side's reported value.

This is the only acceptable way to evolve the surface. Adding optional
fields is fine without bumping; renaming or removing anything requires
the version check above.

## Known gaps

- `MacOSBridge._loggedMissingMethods` is a `Set<String>` that lives for
  the lifetime of the bridge. Restart the app to clear it.
- `FallbackBridge` swallows exceptions silently in some paths; a
  Sentry breadcrumb would help diagnose missing capabilities.
- `CompanionOverlayWindow` (registered in `main_common.dart` at line
  562) shares a single MethodChannel with the dashboard overlay, so
  failures can cascade. Consider splitting it.
- No integration tests against the native side. Everything below this
  paragraph is untested by automation.
