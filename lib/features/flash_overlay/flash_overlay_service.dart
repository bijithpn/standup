import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:standup/core/plugins/windows_overlay_plugin.dart';

/// Service to manage the full-screen flash overlay notification
class FlashOverlayService extends ChangeNotifier {
  Timer? _overlayTimer;
  bool _isOverlayVisible = false;
  final Duration _overlayInterval;
  final Duration _overlayDisplayDuration;

  FlashOverlayService({
    Duration? overlayInterval,
    Duration? overlayDisplayDuration,
  })  : _overlayInterval = overlayInterval ?? const Duration(minutes: 20),
        _overlayDisplayDuration = overlayDisplayDuration ?? const Duration(seconds: 10);

  /// Start the periodic overlay timer
  void startTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer.periodic(_overlayInterval, (_) => showOverlay());
    debugPrint('[FlashOverlay] Timer started with interval: $_overlayInterval');
  }

  /// Stop the overlay timer
  void stopTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    debugPrint('[FlashOverlay] Timer stopped');
  }

  /// Show the flash overlay
  Future<void> showOverlay() async {
    if (_isOverlayVisible) {
      debugPrint('[FlashOverlay] Overlay already visible');
      return;
    }

    debugPrint('[FlashOverlay] Showing overlay');
    _isOverlayVisible = true;
    notifyListeners();

    try {
      // Show overlay window temporarily
      await windowManager.show();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setFullScreen(true);
      await windowManager.setSkipTaskbar(true);
      
      // Platform-specific configurations
      await _configurePlatformOverlay();

      // Auto-hide after display duration
      await Future.delayed(_overlayDisplayDuration);
      await hideOverlay();
    } catch (e) {
      debugPrint('[FlashOverlay] Error showing overlay: $e');
      _isOverlayVisible = false;
      notifyListeners();
    }
  }

  /// Configure platform-specific overlay settings
  Future<void> _configurePlatformOverlay() async {
    // Windows: Use native plugin for better overlay support
    await WindowsOverlayPlugin.configureAsOverlay();
    await WindowsOverlayPlugin.setTransparency(0.95);
  }

  /// Hide the flash overlay and return app to background
  Future<void> hideOverlay() async {
    if (!_isOverlayVisible) {
      debugPrint('[FlashOverlay] Overlay not visible');
      return;
    }

    debugPrint('[FlashOverlay] Hiding overlay');
    _isOverlayVisible = false;
    notifyListeners();

    try {
      // Reset window state - return to background/tray
      await windowManager.setFullScreen(false);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.hide();
      await windowManager.setBackgroundColor(Colors.transparent);
      
      // Platform-specific reset
      await _resetPlatformOverlay();
      
      debugPrint('[FlashOverlay] App returned to background');
    } catch (e) {
      debugPrint('[FlashOverlay] Error hiding overlay: $e');
    }
  }

  /// Reset platform-specific overlay settings
  Future<void> _resetPlatformOverlay() async {
    // Windows: Reset to normal window state
    await WindowsOverlayPlugin.resetToNormal();
  }

  /// Check if overlay is currently visible
  bool get isOverlayVisible => _isOverlayVisible;

  /// Get the current timer interval
  Duration get overlayInterval => _overlayInterval;

  /// Dispose resources
  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
