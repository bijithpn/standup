import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intercepts hardware keyboard events for [StandaloneBreakOverlay].
///
/// Responsibilities:
/// - Listens for emergency quit shortcut (Cmd+Shift+B or Ctrl+Shift+B).
/// - Listens for any non-modifier key to dismiss the overlay when dismissible.
class BreakOverlayKeyboardHandler extends StatefulWidget {
  final bool canDismiss;
  final VoidCallback onSkip;
  final VoidCallback onQuitApp;
  final Widget child;

  const BreakOverlayKeyboardHandler({
    super.key,
    required this.canDismiss,
    required this.onSkip,
    required this.onQuitApp,
    required this.child,
  });

  @override
  State<BreakOverlayKeyboardHandler> createState() =>
      _BreakOverlayKeyboardHandlerState();
}

class _BreakOverlayKeyboardHandlerState
    extends State<BreakOverlayKeyboardHandler> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted) return false;

    final isModifierPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isModifierPressed &&
        HardwareKeyboard.instance.isShiftPressed &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyB) {
      widget.onQuitApp();
      return true;
    }

    // Any key dismisses the overlay when it's allowed to be dismissed
    // (preview, non-strict mode, or a quick reminder/pre-break warning) —
    // don't force the user to sit through the full timer or hunt for the
    // one "correct" key. Bare modifier presses are ignored so they don't
    // eat a real shortcut before its companion key arrives.
    if (widget.canDismiss &&
        event is KeyDownEvent &&
        !_isModifierKey(event.logicalKey)) {
      widget.onSkip();
      return true;
    }
    return false;
  }

  static bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.fn;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
