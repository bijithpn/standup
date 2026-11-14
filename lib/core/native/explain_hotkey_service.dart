import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Registers the system-wide shortcut (Cmd/Ctrl+Alt+E) that triggers the timer explanation overlay.
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
