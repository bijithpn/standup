import 'package:flutter/material.dart';
import 'flash_controller.dart';

/// Full-screen flash overlay widget
/// 
/// This widget creates a semi-transparent overlay that covers the entire screen
/// and animates opacity based on the FlashController state.
class FlashOverlay extends StatelessWidget {
  final FlashController controller;

  const FlashOverlay({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (!controller.isFlashing || controller.currentOpacity <= 0.0) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          // Allow clicks to pass through during flash
          ignoring: true,
          child: Container(
            // Cover the entire screen
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: controller.currentConfig.color
                  .withValues(alpha: controller.currentOpacity * controller.currentConfig.opacity),
            ),
          ),
        );
      },
    );
  }
}

/// Overlay entry wrapper for the flash overlay
class FlashOverlayEntry {
  final OverlayEntry _overlayEntry;

  FlashOverlayEntry._(this._overlayEntry);

  OverlayEntry get entry => _overlayEntry;

  /// Creates a new flash overlay entry
  static FlashOverlayEntry create(FlashController controller) {
    final overlayEntry = OverlayEntry(
      opaque: false,
      maintainState: false,
      builder: (context) {
        return FlashOverlay(controller: controller);
      },
    );
    return FlashOverlayEntry._(overlayEntry);
  }

  /// Insert this overlay entry into the overlay
  void insert() {
    if (!_overlayEntry.mounted) {
      // Insert at the root overlay - topmost
      final overlay = Overlay.of(OverlayContext.overlayKey.currentContext!);
      overlay.insert(_overlayEntry);
    }
  }

  /// Remove this overlay entry
  void remove() {
    if (_overlayEntry.mounted) {
      _overlayEntry.remove();
    }
  }

  /// Mark for removal (triggers fade out animation before actual removal)
  void markForRemoval() {
    _overlayEntry.markNeedsBuild();
  }
}

/// Keys for accessing overlay contexts
class OverlayContext {
  static final GlobalKey overlayKey = GlobalKey();
}
