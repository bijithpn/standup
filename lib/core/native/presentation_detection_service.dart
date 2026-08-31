import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Watches for another app's window covering the whole main display — the
/// shape of a fullscreen slideshow, Keynote/PowerPoint presentation, or a
/// fullscreen video call — and exposes it as [isPresenting].
///
/// This is a heuristic proxy for "the user is presenting or screen-sharing";
/// see `PresentationDetectionBridge.swift` for why true screen-share-state
/// detection isn't available via public APIs. macOS-only; a no-op elsewhere.
class PresentationDetectionService {
  final _channel = const EventChannel('com.breakmate/presentation_detection');
  StreamSubscription? _subscription;
  bool _isRunning = false;
  bool _isPresenting = false;

  bool get isPresenting => _isPresenting;

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.macOS;

  void start() {
    if (_isRunning || !_isSupportedPlatform) return;
    _isRunning = true;

    _subscription = _channel
        .receiveBroadcastStream()
        .map((event) {
          final data = Map<String, dynamic>.from(event);
          return data['isPresenting'] as bool? ?? false;
        })
        .listen(
          (isPresenting) => _isPresenting = isPresenting,
          onError: (error) {
            debugPrint('PresentationDetectionService error: $error');
          },
        );

    debugPrint('PresentationDetectionService started');
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _subscription?.cancel();
    _subscription = null;
    _isPresenting = false;
    debugPrint('PresentationDetectionService stopped');
  }
}
