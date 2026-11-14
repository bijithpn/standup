import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global key handler for the overlay: Escape skips (when allowed); Tab and activation keys stay available to controls; Cmd/Ctrl+Shift+B quits the app even in strict mode.
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

  // Uses HardwareKeyboard (not focus) because the overlay may not hold keyboard focus.
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

    if (widget.canDismiss &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onSkip();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
