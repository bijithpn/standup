import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Registers a second system-wide hotkey (`Cmd+Option+E` on macOS,
/// `Ctrl+Alt+E` on Windows) that opens the "why did BreakMate do that?"
/// explain panel (see `TimerExplanationOverlayService`) — Phase 2 of the
/// workflow-analysis plan doc, ergonomically mirroring Opsis's Quick Ask
/// but scoped to BreakMate's own state, not screen content, and needing no
/// AI call.
///
/// Deliberately a standalone service rather than extending
/// [GlobalHotkeyService] (`⌘⌥B`, break skip/start) — that service's
/// single-hotkey shape is already exercised elsewhere; a second,
/// independent registration is lower risk than generalizing it to carry
/// multiple bindings.
///
/// Desktop-only; a no-op on any other platform.
class ExplainHotkeyService {
  static final HotKey defaultHotKey = HotKey(
    key: PhysicalKeyboardKey.keyE,
    modifiers: defaultTargetPlatform == TargetPlatform.macOS
        ? [HotKeyModifier.meta, HotKeyModifier.alt]
        : [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  bool _isRunning = false;

  bool get isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Registers the hotkey and invokes [onPressed] whenever it fires.
  Future<void> start({required VoidCallback onPressed}) async {
    if (_isRunning || !isSupportedPlatform) return;
    _isRunning = true;
    try {
      await hotKeyManager.register(
        defaultHotKey,
        keyDownHandler: (_) => onPressed(),
      );
    } catch (e) {
      debugPrint('ExplainHotkeyService: failed to register hotkey: $e');
      _isRunning = false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    try {
      await hotKeyManager.unregister(defaultHotKey);
    } catch (e) {
      debugPrint('ExplainHotkeyService: failed to unregister hotkey: $e');
    }
  }
}
