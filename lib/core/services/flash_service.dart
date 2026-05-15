import 'package:flutter/material.dart';
import 'flash_controller.dart';
import 'flash_overlay.dart';

/// Service for triggering full-screen flash effects
/// 
/// This singleton service provides a simple API to trigger
/// full-screen flash animations that behave like macOS/iOS
/// Accessibility "Flash the screen" feature.
/// 
/// Example usage:
/// ```dart
/// // Simple flash with default settings
/// FlashService.flash();
/// 
/// // Flash with custom color
/// FlashService.flash(color: Colors.red);
/// 
/// // Flash with custom configuration
/// FlashService.flash(
///   color: Colors.blueAccent,
///   opacity: 0.7,
///   flashCount: 3,
/// );
/// 
/// // Using predefined configs
/// FlashService.flashPulse(); // 3 rapid flashes
/// FlashService.flashAccessibility(); // Single gentle flash
/// ```
class FlashService {
  static FlashService? _instance;
  
  final FlashController _controller = FlashController();
  OverlayEntry? _overlayEntry;
  bool _isInitialized = false;

  FlashService._();

  /// Get the singleton instance
  static FlashService get instance {
    _instance ??= FlashService._();
    return _instance!;
  }

  /// Get the underlying controller (for advanced usage)
  FlashController get controller => _controller;

  /// Check if flash is currently active
  bool get isFlashing => _controller.isFlashing;

  /// Initialize the flash service
  /// Must be called before first use
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Trigger a flash with customizable options
  /// 
  /// Parameters:
  /// - [color]: The color of the flash (default: white)
  /// - [opacity]: Maximum opacity of the overlay (default: 0.8)
  /// - [flashCount]: Number of flash pulses (default: 1)
  /// - [duration]: Total duration of the flash (default: 400ms)
  /// - [flashInDuration]: Time to reach full opacity (default: 80ms)
  /// - [holdDuration]: Time to hold at full opacity (default: 120ms)
  /// - [fadeOutDuration]: Time to fade out (default: 200ms)
  Future<void> flash({
    Color color = Colors.white,
    double opacity = 0.8,
    int flashCount = 1,
    Duration? duration,
    Duration? flashInDuration,
    Duration? holdDuration,
    Duration? fadeOutDuration,
  }) async {
    if (!_isInitialized) {
      initialize();
    }

    final config = FlashConfig(
      color: color,
      opacity: opacity,
      flashCount: flashCount,
      duration: duration ?? const Duration(milliseconds: 400),
      flashInDuration: flashInDuration ?? const Duration(milliseconds: 80),
      holdDuration: holdDuration ?? const Duration(milliseconds: 120),
      fadeOutDuration: fadeOutDuration ?? const Duration(milliseconds: 200),
    );

    await _triggerFlash(config);
  }

  /// Trigger a flash with a custom configuration object
  Future<void> flashWithConfig(FlashConfig config) async {
    if (!_isInitialized) {
      initialize();
    }
    await _triggerFlash(config);
  }

  /// Trigger an accessibility-style flash (gentle, single pulse)
  Future<void> flashAccessibility({Color color = Colors.white}) async {
    await flash(
      color: color,
      opacity: 0.7,
      flashCount: 1,
    );
  }

  /// Trigger a pulse flash (multiple rapid flashes)
  Future<void> flashPulse({
    Color color = Colors.white,
    int flashCount = 3,
  }) async {
    await flash(
      color: color,
      opacity: 0.6,
      flashCount: flashCount,
    );
  }

  /// Stop any ongoing flash animation
  Future<void> stop() async {
    await _controller.stop();
    _removeOverlay();
  }

  /// Internal method to trigger flash
  Future<void> _triggerFlash(FlashConfig config) async {
    // Ensure overlay exists
    _ensureOverlay();

    // Start the flash animation
    await _controller.flash(config);

    // Clean up overlay after animation completes
    _removeOverlay();
  }

  /// Ensure the overlay entry exists and is inserted
  void _ensureOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        opaque: false,
        maintainState: false,
        builder: (context) {
          return FlashOverlay(controller: _controller);
        },
      );

      // Insert into the root overlay
      try {
        final overlayContext = OverlayContext.overlayKey.currentContext;
        if (overlayContext != null) {
          final overlay = Overlay.of(overlayContext);
          overlay.insert(_overlayEntry!);
        }
      } catch (e) {
        // Overlay might not be available yet
        debugPrint('FlashService: Could not insert overlay - $e');
      }
    }
  }

  /// Remove the overlay entry
  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  /// Dispose of resources
  void dispose() {
    _controller.dispose();
    _removeOverlay();
    _isInitialized = false;
  }
}

/// Extension for easy access from BuildContext
extension FlashServiceExtension on BuildContext {
  /// Trigger a flash from any widget context
  Future<void> flashScreen({
    Color color = Colors.white,
    double opacity = 0.8,
    int flashCount = 1,
  }) async {
    await FlashService.instance.flash(
      color: color,
      opacity: opacity,
      flashCount: flashCount,
    );
  }
}
