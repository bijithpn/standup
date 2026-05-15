import 'dart:async';
import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/overlay_window_service.dart';

/// Service to manage the full-screen flash overlay notification
class FlashOverlayService extends ChangeNotifier {
  Timer? _overlayTimer;
  bool _isOverlayVisible = false;
  final Duration _overlayInterval;
  final Duration _overlayDisplayDuration;
  final OverlayWindowService _overlayService = sl<OverlayWindowService>();

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
      // Use the consolidated overlay service
      await _overlayService.showOverlay(
        type: OverlayType.flashNotification,
        builder: (_) => const SizedBox.shrink(), // Content is handled in app.dart's Stack
        strictMode: false,
      );

      // Auto-hide after display duration
      await Future.delayed(_overlayDisplayDuration);
      await hideOverlay();
    } catch (e) {
      debugPrint('[FlashOverlay] Error showing overlay: $e');
      _isOverlayVisible = false;
      notifyListeners();
    }
  }

  /// Hide the flash overlay and return app to background
  Future<void> hideOverlay() async {
    if (!_isOverlayVisible) return;

    debugPrint('[FlashOverlay] Hiding overlay');
    _isOverlayVisible = false;
    notifyListeners();

    try {
      await _overlayService.hideOverlay();
      debugPrint('[FlashOverlay] App returned to background');
    } catch (e) {
      debugPrint('[FlashOverlay] Error hiding overlay: $e');
    }
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
