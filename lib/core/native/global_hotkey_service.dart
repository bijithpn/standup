import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Registers a single system-wide hotkey (default `Cmd+Option+B` on macOS,
/// `Ctrl+Alt+B` on Windows) that either starts a break immediately, or —
/// if a break is already active — skips it.
///
/// Desktop-only; a no-op on any other platform.
class GlobalHotkeyService {
  static final HotKey defaultHotKey = HotKey(
    key: PhysicalKeyboardKey.keyB,
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
      debugPrint('GlobalHotkeyService: failed to register hotkey: $e');
      _isRunning = false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    try {
      await hotKeyManager.unregister(defaultHotKey);
    } catch (e) {
      debugPrint('GlobalHotkeyService: failed to unregister hotkey: $e');
    }
  }
}
