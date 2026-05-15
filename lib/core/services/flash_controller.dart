import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Configuration for flash effect
class FlashConfig {
  final Color color;
  final double opacity;
  final Duration duration;
  final int flashCount;
  final Duration flashInDuration;
  final Duration holdDuration;
  final Duration fadeOutDuration;

  const FlashConfig({
    this.color = Colors.white,
    this.opacity = 0.8,
    this.duration = const Duration(milliseconds: 400),
    this.flashCount = 1,
    this.flashInDuration = const Duration(milliseconds: 80),
    this.holdDuration = const Duration(milliseconds: 120),
    this.fadeOutDuration = const Duration(milliseconds: 200),
  });

  /// Creates a flash config optimized for accessibility alerts
  const FlashConfig.accessibility({
    this.color = Colors.white,
    this.opacity = 0.7,
    this.flashCount = 1,
  }) : duration = const Duration(milliseconds: 400),
       flashInDuration = const Duration(milliseconds: 80),
       holdDuration = const Duration(milliseconds: 120),
       fadeOutDuration = const Duration(milliseconds: 200);

  /// Creates a flash config with multiple pulses
  const FlashConfig.pulse({
    this.color = Colors.white,
    this.opacity = 0.6,
    this.flashCount = 3,
  }) : duration = const Duration(milliseconds: 1200),
       flashInDuration = const Duration(milliseconds: 80),
       holdDuration = const Duration(milliseconds: 120),
       fadeOutDuration = const Duration(milliseconds: 200);

  /// Total duration for a single flash
  Duration get singleFlashDuration => flashInDuration + holdDuration + fadeOutDuration;

  /// Total duration for all flashes
  Duration get totalDuration => singleFlashDuration * flashCount;
}

/// Controller for managing flash animations
class FlashController extends ChangeNotifier {
  FlashConfig _currentConfig = const FlashConfig.accessibility();
  bool _isFlashing = false;
  int _currentFlashIndex = 0;
  double _currentOpacity = 0.0;
  Timer? _animationTimer;

  FlashConfig get currentConfig => _currentConfig;
  bool get isFlashing => _isFlashing;
  int get currentFlashIndex => _currentFlashIndex;
  double get currentOpacity => _currentOpacity;

  /// Start the flash animation sequence
  Future<void> flash(FlashConfig config) async {
    if (_isFlashing) {
      // Queue the flash or interrupt current - here we interrupt
      await stop();
    }

    _currentConfig = config;
    _isFlashing = true;
    _currentFlashIndex = 0;
    notifyListeners();

    try {
      await _runFlashSequence();
    } finally {
      _isFlashing = false;
      _currentFlashIndex = 0;
      _currentOpacity = 0.0;
      notifyListeners();
    }
  }

  /// Stop the current flash animation
  Future<void> stop() async {
    _animationTimer?.cancel();
    _animationTimer = null;
    _isFlashing = false;
    _currentOpacity = 0.0;
    notifyListeners();
  }

  /// Run the complete flash sequence
  Future<void> _runFlashSequence() async {
    for (int i = 0; i < _currentConfig.flashCount; i++) {
      _currentFlashIndex = i;
      notifyListeners();
      
      await _runSingleFlash();
      
      // Add a small delay between flashes if there are more to come
      if (i < _currentConfig.flashCount - 1) {
        await Future.delayed(_currentConfig.fadeOutDuration);
      }
    }
  }

  /// Run a single flash animation
  Future<void> _runSingleFlash() async {
    final completer = Completer<void>();
    
    // Flash in - rapid opacity increase
    _animateOpacity(
      from: 0.0,
      to: _currentConfig.opacity,
      duration: _currentConfig.flashInDuration,
    );
    
    await Future.delayed(_currentConfig.flashInDuration);
    
    // Hold - maintain opacity
    _currentOpacity = _currentConfig.opacity;
    notifyListeners();
    
    await Future.delayed(_currentConfig.holdDuration);
    
    // Fade out - smooth decrease
    _animateOpacity(
      from: _currentConfig.opacity,
      to: 0.0,
      duration: _currentConfig.fadeOutDuration,
    );
    
    await Future.delayed(_currentConfig.fadeOutDuration);
    
    _currentOpacity = 0.0;
    notifyListeners();
    
    completer.complete();
    await completer.future;
  }

  /// Animate opacity with smooth interpolation
  void _animateOpacity({
    required double from,
    required double to,
    required Duration duration,
  }) {
    const int frameIntervalMs = 16; // ~60fps
    final int totalFrames = (duration.inMilliseconds / frameIntervalMs).ceil();
    int currentFrame = 0;

    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(
      Duration(milliseconds: frameIntervalMs),
      (timer) {
        currentFrame++;
        final progress = currentFrame / totalFrames;
        
        // Use ease-out cubic for smooth animation
        final easedProgress = _easeOutCubic(progress.clamp(0.0, 1.0));
        _currentOpacity = from + (to - from) * easedProgress;
        notifyListeners();

        if (currentFrame >= totalFrames) {
          timer.cancel();
          _animationTimer = null;
        }
      },
    );
  }

  /// Ease-out cubic interpolation for smooth animations
  double _easeOutCubic(double t) {
    return 1 - math.pow(1 - t, 3).toDouble();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }
}
